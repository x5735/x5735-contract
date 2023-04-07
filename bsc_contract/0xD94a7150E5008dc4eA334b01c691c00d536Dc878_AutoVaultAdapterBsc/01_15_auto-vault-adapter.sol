// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../interfaces/IVaultStrategy.sol";
import "../../interfaces/IHedgepieInvestor.sol";
import "../../libraries/HedgepieLibraryBsc.sol";

interface IStrategy {
    function pendingAUTO(
        uint256 pid,
        address user
    ) external view returns (uint256);

    function userInfo(
        uint256 pid,
        address user
    ) external view returns (uint256, uint256);

    function deposit(uint256 pid, uint256 shares) external;

    function withdraw(uint256 pid, uint256 shares) external;
}

contract AutoVaultAdapterBsc is BaseAdapter {
    // vStrategy address of vault
    address public vStrategy;

    /**
     * @notice Construct
     * @param _pid pool id of strategy
     * @param _strategy  address of strategy
     * @param _vStrategy  address of vault strategy
     * @param _stakingToken  address of staking token
     * @param _router  address of DEX router
     * @param _swapRouter  address of swap router
     * @param _wbnb  address of wbnb
     * @param _name  adatper name
     */
    constructor(
        uint256 _pid,
        address _strategy,
        address _vStrategy,
        address _stakingToken,
        address _router,
        address _swapRouter,
        address _wbnb,
        string memory _name,
        address _hedgepieAuthority
    ) BaseAdapter(_hedgepieAuthority) {
        pid = _pid;
        strategy = _strategy;
        vStrategy = _vStrategy;
        stakingToken = _stakingToken;
        router = _router;
        swapRouter = _swapRouter;
        wbnb = _wbnb;
        name = _name;
    }

    /**
     * @notice Deposit with Bnb
     * @param _tokenId YBNFT token id
     */
    function deposit(
        uint256 _tokenId
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];

        // get LP
        amountOut = HedgepieLibraryBsc.getLP(
            IYBNFT.AdapterParam(0, stakingToken, address(this)),
            wbnb,
            msg.value
        );

        // deposit
        (uint256 beforeShare, ) = IStrategy(strategy).userInfo(
            pid,
            address(this)
        );
        IERC20(stakingToken).approve(strategy, amountOut);
        IStrategy(strategy).deposit(pid, amountOut);
        (uint256 afterShare, ) = IStrategy(strategy).userInfo(
            pid,
            address(this)
        );
        require(afterShare > beforeShare, "Failed to deposit");

        userInfo.amount += afterShare - beforeShare;
        userInfo.invested += amountOut;

        return msg.value;
    }

    /**
     * @notice Withdraw the deposited Bnb
     * @param _tokenId YBNFT token id
     * @param _amount amount of staking token to withdraw
     */
    function withdraw(
        uint256 _tokenId,
        uint256 _amount
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];

        if (_amount == 0) return 0;

        // withdraw from Vault
        uint256 vAmount = (_amount *
            IVaultStrategy(vStrategy).wantLockedTotal()) /
            IVaultStrategy(vStrategy).sharesTotal();
        uint256 lpOut = IERC20(stakingToken).balanceOf(address(this));
        IStrategy(strategy).withdraw(pid, vAmount);
        lpOut = IERC20(stakingToken).balanceOf(address(this)) - lpOut;

        amountOut = HedgepieLibraryBsc.withdrawLP(
            IYBNFT.AdapterParam(0, stakingToken, address(this)),
            wbnb,
            lpOut
        );

        // update userInfo
        userInfo.amount -= _amount;
        if (lpOut >= userInfo.invested) userInfo.invested = 0;
        else userInfo.invested -= lpOut;

        // send withdrawn bnb
        if (amountOut != 0) {
            (bool success, ) = payable(msg.sender).call{value: amountOut}("");
            require(success, "Failed to send bnb");
        }
    }

    /**
     * @notice Claim the pending reward
     * @param _tokenId YBNFT token id
     */
    function claim(
        uint256 _tokenId
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];

        uint256 vAmount = (userInfo.amount *
            IVaultStrategy(vStrategy).wantLockedTotal()) /
            IVaultStrategy(vStrategy).sharesTotal();

        if (vAmount <= userInfo.invested) {
            if (userInfo.rewardDebt1 == 0) return 0;

            amountOut = userInfo.rewardDebt1;
            userInfo.rewardDebt1 = 0;

            // send reward in bnb
            if (amountOut != 0) {
                uint256 taxAmount = (amountOut *
                    IYBNFT(authority.hYBNFT()).performanceFee(_tokenId)) / 1e4;
                (bool success, ) = payable(
                    IHedgepieInvestor(authority.hInvestor()).treasury()
                ).call{value: taxAmount}("");
                require(success, "Failed to send bnb to Treasury");

                (success, ) = payable(msg.sender).call{
                    value: amountOut - taxAmount
                }("");
                require(success, "Failed to send bnb");
            }

            return amountOut;
        }

        // if there's a reward from vault
        vAmount -= userInfo.invested;

        uint256 lpOut = IERC20(stakingToken).balanceOf(address(this));
        IStrategy(strategy).withdraw(pid, vAmount);
        lpOut = IERC20(stakingToken).balanceOf(address(this)) - lpOut;

        amountOut =
            HedgepieLibraryBsc.withdrawLP(
                IYBNFT.AdapterParam(0, stakingToken, address(this)),
                wbnb,
                lpOut
            ) +
            userInfo.rewardDebt1;

        // update user info
        userInfo.rewardDebt1 = 0;

        // send reward in bnb
        if (amountOut != 0) {
            uint256 taxAmount = (amountOut *
                IYBNFT(authority.hYBNFT()).performanceFee(_tokenId)) / 1e4;
            (bool success, ) = payable(
                IHedgepieInvestor(authority.hInvestor()).treasury()
            ).call{value: taxAmount}("");
            require(success, "Failed to send bnb to Treasury");

            (success, ) = payable(msg.sender).call{
                value: amountOut - taxAmount
            }("");
            require(success, "Failed to send bnb");
        }
    }

    /**
     * @notice Return the pending reward by BNB
     * @param _tokenId YBNFT token id
     */
    function pendingReward(
        uint256 _tokenId
    ) external view override returns (uint256 reward, uint256) {
        UserAdapterInfo memory userInfo = userAdapterInfos[_tokenId];

        uint256 vAmount = (userInfo.amount *
            IVaultStrategy(vStrategy).wantLockedTotal()) /
            IVaultStrategy(vStrategy).sharesTotal();

        if (vAmount <= userInfo.invested)
            return (userInfo.rewardDebt1, userInfo.rewardDebt1);
        vAmount -= userInfo.invested;

        address token0 = IPancakePair(stakingToken).token0();
        address token1 = IPancakePair(stakingToken).token1();
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(stakingToken)
            .getReserves();

        uint256 amount0 = (reserve0 * vAmount) /
            IPancakePair(stakingToken).totalSupply();
        uint256 amount1 = (reserve1 * vAmount) /
            IPancakePair(stakingToken).totalSupply();

        if (token0 == wbnb) reward += amount0;
        else
            reward += amount0 == 0
                ? 0
                : IPancakeRouter(swapRouter).getAmountsOut(
                    amount0,
                    IPathFinder(authority.pathFinder()).getPaths(
                        swapRouter,
                        token0,
                        wbnb
                    )
                )[
                        IPathFinder(authority.pathFinder())
                            .getPaths(swapRouter, token0, wbnb)
                            .length - 1
                    ];

        if (token1 == wbnb) reward += amount1;
        else
            reward += amount1 == 0
                ? 0
                : IPancakeRouter(swapRouter).getAmountsOut(
                    amount1,
                    IPathFinder(authority.pathFinder()).getPaths(
                        swapRouter,
                        token1,
                        wbnb
                    )
                )[
                        IPathFinder(authority.pathFinder())
                            .getPaths(swapRouter, token1, wbnb)
                            .length - 1
                    ];

        return (reward + userInfo.rewardDebt1, reward + userInfo.rewardDebt1);
    }

    /**
     * @notice Remove funds
     * @param _tokenId YBNFT token id
     */
    function removeFunds(
        uint256 _tokenId
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];
        if (userInfo.amount == 0) return 0;

        // withdraw from Vault
        amountOut = IERC20(stakingToken).balanceOf(address(this));
        uint256 vAmount = (userInfo.amount *
            IVaultStrategy(vStrategy).wantLockedTotal()) /
            IVaultStrategy(vStrategy).sharesTotal();
        IStrategy(strategy).withdraw(pid, vAmount);
        amountOut = IERC20(stakingToken).balanceOf(address(this)) - amountOut;

        // calc reward
        uint256 rewardPercent = 0;
        if (amountOut > userInfo.invested) {
            rewardPercent =
                ((amountOut - userInfo.invested) * 1e12) /
                amountOut;
        }

        // swap withdrawn lp to bnb
        if (router == address(0)) {
            amountOut = HedgepieLibraryBsc.swapForBnb(
                amountOut,
                address(this),
                stakingToken,
                swapRouter,
                wbnb
            );
        } else {
            amountOut = HedgepieLibraryBsc.withdrawLP(
                IYBNFT.AdapterParam(0, stakingToken, address(this)),
                wbnb,
                amountOut
            );
        }

        // remove userInfo and stake pendingReward to rewardDebt1
        uint256 reward = (amountOut * rewardPercent) / 1e12;
        userInfo.amount = 0;
        userInfo.invested = 0;
        userInfo.rewardDebt1 += reward;

        // send to investor
        (bool success, ) = payable(authority.hInvestor()).call{
            value: amountOut - reward
        }("");
        require(success, "Failed to send bnb to investor");
    }

    /**
     * @notice Update funds
     * @param _tokenId YBNFT token id
     */
    function updateFunds(
        uint256 _tokenId
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        if (msg.value == 0) return 0;

        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];

        // get LP
        amountOut = HedgepieLibraryBsc.getLP(
            IYBNFT.AdapterParam(0, stakingToken, address(this)),
            wbnb,
            msg.value
        );

        // deposit
        (uint256 beforeShare, ) = IStrategy(strategy).userInfo(
            pid,
            address(this)
        );
        IERC20(stakingToken).approve(strategy, amountOut);
        IStrategy(strategy).deposit(pid, amountOut);
        (uint256 afterShare, ) = IStrategy(strategy).userInfo(
            pid,
            address(this)
        );
        require(afterShare > beforeShare, "Failed to update funds");

        userInfo.amount = afterShare - beforeShare;
        userInfo.invested = amountOut;

        return msg.value;
    }

    receive() external payable {}
}