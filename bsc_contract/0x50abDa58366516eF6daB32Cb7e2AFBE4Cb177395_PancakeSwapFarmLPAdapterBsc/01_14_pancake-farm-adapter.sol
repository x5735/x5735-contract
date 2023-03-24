// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../libraries/HedgepieLibraryBsc.sol";
import "../../interfaces/IHedgepieInvestor.sol";

interface IStrategy {
    function pendingCake(
        uint256 _pid,
        address _user
    ) external view returns (uint256);

    function deposit(uint256 pid, uint256 shares) external;

    function withdraw(uint256 pid, uint256 shares) external;
}

contract PancakeSwapFarmLPAdapterBsc is BaseAdapter {
    /**
     * @notice Construct
     * @param _pid  pool id of strategy
     * @param _strategy  address of strategy
     * @param _stakingToken  address of staking token
     * @param _rewardToken  address of reward token
     * @param _router  address of router for lp token
     * @param _wbnb  wbnb address
     * @param _name  adatper name
     * @param _hedgepieAuthority  hedgepieAuthority address
     */
    constructor(
        uint256 _pid,
        address _strategy,
        address _stakingToken,
        address _rewardToken,
        address _router,
        address _wbnb,
        string memory _name,
        address _hedgepieAuthority
    ) BaseAdapter(_hedgepieAuthority) {
        pid = _pid;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        strategy = _strategy;
        router = _router;
        swapRouter = _router;
        wbnb = _wbnb;
        name = _name;
    }

    /**
     * @notice Deposit with BNB
     * @param _tokenId YBNFT token id
     */
    function deposit(
        uint256 _tokenId
    ) external payable override onlyInvestor returns (uint256 amountOut) {
        UserAdapterInfo storage userInfo = userAdapterInfos[_tokenId];

        // swap to staking token
        if (router == address(0)) {
            amountOut = HedgepieLibraryBsc.swapOnRouter(
                msg.value,
                address(this),
                stakingToken,
                router,
                wbnb
            );
        } else {
            amountOut = HedgepieLibraryBsc.getLP(
                IYBNFT.AdapterParam(0, stakingToken, address(this)),
                wbnb,
                msg.value
            );
        }

        // calc rewardToken amount
        uint256 rewardAmt0;
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this));
        IERC20(stakingToken).approve(strategy, amountOut);
        IStrategy(strategy).deposit(pid, amountOut);
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this)) - rewardAmt0;

        // update accTokenPerShare if reward is generated
        if (
            rewardAmt0 != 0 &&
            rewardToken != address(0) &&
            mAdapter.totalStaked != 0
        ) {
            mAdapter.accTokenPerShare1 +=
                (rewardAmt0 * 1e12) /
                mAdapter.totalStaked;
        }

        // update user's rewardDebt value when user staked several times
        if (userInfo.amount != 0) {
            userInfo.rewardDebt1 +=
                (userInfo.amount *
                    (mAdapter.accTokenPerShare1 - userInfo.userShare1)) /
                1e12;
        }

        // update mAdapter & userInfo
        userInfo.amount += amountOut;
        userInfo.userShare1 = mAdapter.accTokenPerShare1;
        mAdapter.totalStaked += amountOut;

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

        // validation of _amount parameter
        require(_amount <= userInfo.amount, "Not enough balance to withdraw");

        // calc reward and withdrawn amount
        uint256 rewardAmt0 = IERC20(rewardToken).balanceOf(address(this));
        amountOut = IERC20(stakingToken).balanceOf(address(this));
        IStrategy(strategy).withdraw(pid, _amount);
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this)) - rewardAmt0;
        amountOut = IERC20(stakingToken).balanceOf(address(this)) - amountOut;
        require(_amount == amountOut, "Failed to withdraw");

        // update accTokenPerShare if reward is generated
        if (rewardAmt0 != 0 && rewardToken != address(0)) {
            mAdapter.accTokenPerShare1 +=
                (rewardAmt0 * 1e12) /
                mAdapter.totalStaked;
        }

        // swap withdrawn staking tokens to bnb
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

        // get user's rewards
        (uint256 reward, ) = HedgepieLibraryBsc.getMRewards(
            _tokenId,
            address(this)
        );

        // swap reward to bnb
        uint256 rewardBnb;
        if (reward != 0) {
            rewardBnb = HedgepieLibraryBsc.swapForBnb(
                reward,
                address(this),
                rewardToken,
                swapRouter,
                wbnb
            );
        }

        if (rewardBnb != 0) amountOut += rewardBnb;

        // update mAdapter & user Info
        mAdapter.totalStaked -= _amount;
        userInfo.amount -= _amount;
        userInfo.userShare1 = mAdapter.accTokenPerShare1;
        userInfo.rewardDebt1 = 0;

        if (amountOut != 0) {
            bool success;
            if (rewardBnb != 0) {
                rewardBnb =
                    (rewardBnb *
                        IYBNFT(authority.hYBNFT()).performanceFee(_tokenId)) /
                    1e4;
                (success, ) = payable(
                    IHedgepieInvestor(authority.hInvestor()).treasury()
                ).call{value: rewardBnb}("");
                require(success, "Failed to send bnb to Treasury");
            }

            (success, ) = payable(msg.sender).call{
                value: amountOut - rewardBnb
            }("");
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

        // claim rewards
        uint256 rewardAmt0 = IERC20(rewardToken).balanceOf(address(this));
        IStrategy(strategy).withdraw(pid, 0);
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this)) - rewardAmt0;
        if (
            rewardAmt0 != 0 &&
            rewardToken != address(0) &&
            mAdapter.totalStaked != 0
        ) {
            mAdapter.accTokenPerShare1 +=
                (rewardAmt0 * 1e12) /
                mAdapter.totalStaked;
        }

        // get user's rewards
        (uint256 reward, ) = HedgepieLibraryBsc.getMRewards(
            _tokenId,
            address(this)
        );

        // update user info
        userInfo.userShare1 = mAdapter.accTokenPerShare1;
        userInfo.rewardDebt1 = 0;

        if (reward != 0 && rewardToken != address(0)) {
            amountOut += HedgepieLibraryBsc.swapForBnb(
                reward,
                address(this),
                rewardToken,
                swapRouter,
                wbnb
            );

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
     * @notice Return the pending reward by Bnb
     * @param _tokenId YBNFT token id
     */
    function pendingReward(
        uint256 _tokenId
    ) external view override returns (uint256 reward, uint256 withdrawable) {
        UserAdapterInfo memory userInfo = userAdapterInfos[_tokenId];

        uint256 updatedAccTokenPerShare = mAdapter.accTokenPerShare1;
        if (mAdapter.totalStaked != 0)
            updatedAccTokenPerShare += ((IStrategy(strategy).pendingCake(
                pid,
                address(this)
            ) * 1e12) / mAdapter.totalStaked);

        uint256 tokenRewards = ((updatedAccTokenPerShare -
            userInfo.userShare1) * userInfo.amount) /
            1e12 +
            userInfo.rewardDebt1;

        if (tokenRewards != 0) {
            reward = rewardToken == wbnb
                ? tokenRewards
                : IPancakeRouter(swapRouter).getAmountsOut(
                    tokenRewards,
                    IPathFinder(authority.pathFinder()).getPaths(
                        swapRouter,
                        rewardToken,
                        wbnb
                    )
                )[
                        IPathFinder(authority.pathFinder())
                            .getPaths(swapRouter, rewardToken, wbnb)
                            .length - 1
                    ];
            withdrawable = reward;
        }
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

        // update reward infor after withdraw all staking tokens
        uint256 rewardAmt0 = IERC20(rewardToken).balanceOf(address(this));
        amountOut = IERC20(stakingToken).balanceOf(address(this));
        IStrategy(strategy).withdraw(pid, userInfo.amount);
        amountOut = IERC20(stakingToken).balanceOf(address(this)) - amountOut;
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this)) - rewardAmt0;
        require(userInfo.amount == amountOut, "Failed to remove funds");

        if (rewardAmt0 != 0 && rewardToken != address(0)) {
            mAdapter.accTokenPerShare1 +=
                (rewardAmt0 * 1e12) /
                mAdapter.totalStaked;
        }

        if (userInfo.amount != 0) {
            userInfo.rewardDebt1 +=
                (userInfo.amount *
                    (mAdapter.accTokenPerShare1 - userInfo.userShare1)) /
                1e12;
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

        // update invested information for token id
        mAdapter.totalStaked -= userInfo.amount;
        userInfo.amount = 0;
        userInfo.userShare1 = mAdapter.accTokenPerShare1;

        // send to investor
        (bool success, ) = payable(authority.hInvestor()).call{
            value: amountOut
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

        // swap bnb to staking token
        if (router == address(0)) {
            amountOut = HedgepieLibraryBsc.swapOnRouter(
                msg.value,
                address(this),
                stakingToken,
                swapRouter,
                wbnb
            );
        } else {
            amountOut = HedgepieLibraryBsc.getLP(
                IYBNFT.AdapterParam(0, stakingToken, address(this)),
                wbnb,
                msg.value
            );
        }
        uint256 rewardAmt0 = IERC20(rewardToken).balanceOf(address(this));
        IERC20(stakingToken).approve(strategy, amountOut);
        IStrategy(strategy).deposit(pid, amountOut);
        rewardAmt0 = IERC20(rewardToken).balanceOf(address(this)) - rewardAmt0;

        // update reward infor
        if (
            rewardAmt0 != 0 &&
            rewardToken != address(0) &&
            mAdapter.totalStaked != 0
        ) {
            mAdapter.accTokenPerShare1 +=
                (rewardAmt0 * 1e12) /
                mAdapter.totalStaked;
        }

        mAdapter.totalStaked += amountOut;
        userInfo.amount = amountOut;
        userInfo.userShare1 = mAdapter.accTokenPerShare1;

        return msg.value;
    }

    receive() external payable {}
}