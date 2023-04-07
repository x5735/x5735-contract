// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./Pusable.sol";
import "./library/NewSafeMath.sol";
import "./library/NewSafeERC20.sol";
import "./interface/IBiswapfarm.sol";
import "./interface/IBiswapRouter02.sol";
import "./interface/IPancakeRouter02.sol";
import "./interface/IBiswapPair.sol";
import "./interface/IStrategy.sol";

contract StratX_pancakeLP is Ownable, ReentrancyGuard, Pausable, IStrategy {
    // Maximises yields in pancakeswap
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //------------==
    bool public isCAKEStaking = false;
    bool public isAfiComp = true;
    uint256 public pid;
    address public wantAddress;
    address public token0Address;
    address public token1Address;

    address public farmContractAddress =
        0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    address public constant earnedAddress =
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; //cake

    //------------==

    // comment WBNB out since we are going to replace it with USDT
    // address public constant wbnb =
    //     address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address public constant busd =
        address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address public constant aqua =
        address(0x72B7D61E8fC8cF971960DD9cfA59B8C829D91991);
    address public constant usdt =
        address(0x55d398326f99059fF775485246999027B3197955);
    address public constant usdc =
        address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    address public constant unirouterbiswap =
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E); //biSWAP
    address public constant masterchef =
        address(0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652);

    uint256 public WITHDRAWAL_FEE = 10;
    uint256 public constant WITHDRAWAL_MAX = 10000;

    uint256 public PLANET_WITHDRAW_FEE = 0;
    uint256 public PLANET_DEPOSIT_FEE = 0;
    uint256 public constant PLANET_MAX = 10000;

    // ---------------==
    address public constant uniRouterAddress =
        0x10ED43C718714eb63d5aA57B78B54704E256024E; //pancakeswap
    //address public constant wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public afiFarmAddress;
    //address public constant AFIAddress = 0xcf496c03F630C343333a28749a7FC4d589b1137A;//AFIX
    address public AFIAddress; //AFIB

    address public govAddress;

    address public receiveFee =
        address(0x69F3BA775f9B99a0Ff6f74D9BC8080E96b3a681d); //

    address public  fundManager = address(0x8b4Db882711768Dd29B93B7c3F657591F25Cf498);
    address public  fundManager2 = address(0xB278744677c69AdEa58248Dd8a49D92B9A57d6f0); 
    address public  fundManager3 = address(0x2D267Ee1262bCdB29a4866527ff15eb845715503);

    bool public onlyGov = true;

    uint256 public lastEarnBlock = 0;
    uint256 public override wantLockedTotal = 0;
    uint256 public override sharesTotal = 0;

    uint256 public controllerFee = 2800;
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 6000;

    uint256 public buyBackRate = 4200;
    uint256 public constant buyBackRateMax = 10000; // 100 = 1%
    uint256 public constant buyBackRateUL = 6000;
    address public constant buyBackAddress =
        0x000000000000000000000000000000000000dEaD;

    uint256 public constant entranceFeeFactor = 10000; // < 0.1% entrance fee - goes to pool + prevents front-running
    uint256 public constant entranceFeeFactorMax = 10000;
    uint256 public constant entranceFeeFactorLL = 9950; // 0.5% is the max entrance fee settable. LL = lowerlimit

    address[] public earnedToAFIPath = [earnedAddress, usdt, AFIAddress];
    address[] public earnedToToken0Path;
    address[] public earnedToToken1Path;
    address[] public token0ToEarnedPath;
    address[] public token1ToEarnedPath;
    address[] public earnedToUsdtPath = [earnedAddress, usdt];
    address[] public usdtToAFIPath = [usdt, AFIAddress];
    address[] public usdtToToken0Path = [usdt, token0Address];
    address[] public usdtToToken1Path = [usdt, token1Address];

    //address public buybackstrat;
    bool public enableAddLiquidity = true;

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;

    constructor(address _govAddress, address _afiFarmAddress, address _AFIAddress) public {
        govAddress = _govAddress;
        afiFarmAddress = _afiFarmAddress;
        AFIAddress = _AFIAddress;

        wantAddress = 0xA39Af17CE4a8eb807E076805Da1e2B8EA7D0755b;
        pid = 47;
        token0Address = IBiswapPair(wantAddress).token0();
        token1Address = IBiswapPair(wantAddress).token1();
        usdtToToken0Path = [usdt, token0Address];
        usdtToToken1Path = [usdt, token1Address];

        if (token0Address == busd) {
            earnedToToken0Path = [earnedAddress, usdt, busd];
        } else if (token0Address != earnedAddress) {
            earnedToToken0Path = [earnedAddress, usdt, busd, token0Address];
        }

        if (token1Address == busd) {
            earnedToToken1Path = [earnedAddress, usdt, busd];
        } else if (token1Address != earnedAddress) {
            earnedToToken1Path = [earnedAddress, usdt, busd, token1Address];
        }

        IERC20(wantAddress).safeApprove(masterchef, uint256(-1));
        IERC20(earnedAddress).safeApprove(unirouterbiswap, uint256(-1));
        IERC20(usdt).safeApprove(unirouterbiswap, uint256(-1));

        IERC20(token0Address).safeApprove(unirouterbiswap, 0);
        IERC20(token0Address).safeApprove(unirouterbiswap, uint256(-1));

        IERC20(token1Address).safeApprove(unirouterbiswap, 0);
        IERC20(token1Address).safeApprove(unirouterbiswap, uint256(-1));

        transferOwnership(afiFarmAddress);

    }

    // Receives new deposits from user
    function deposit(address _userAddress, uint256 _wantAmt)
        public override
        onlyOwner
        whenNotPaused
        returns (uint256)
    {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );
        if (PLANET_DEPOSIT_FEE > 0) {
            _wantAmt = _wantAmt.mul(PLANET_MAX.sub(PLANET_DEPOSIT_FEE)).div(
                PLANET_MAX
            );
        } else {
            _wantAmt = _wantAmt.sub(1);
        }

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
            sharesTotal = sharesTotal.add(sharesAdded);
        } else {
            sharesTotal = sharesTotal
                .add(sharesAdded)
                .mul(entranceFeeFactor)
                .div(entranceFeeFactorMax);
        }

        if (isAfiComp) {
            _farm();
        } else {
            wantLockedTotal = wantLockedTotal.add(_wantAmt);
        }

        return sharesAdded;
    }

    function farm() public override nonReentrant {
        _farm();
    }

    function _farm() internal {
        uint256 pairBal = IERC20(wantAddress).balanceOf(address(this));
        if (PLANET_DEPOSIT_FEE > 0) {
            wantLockedTotal = wantLockedTotal.add(
                pairBal.mul(PLANET_MAX.sub(PLANET_DEPOSIT_FEE)).div(PLANET_MAX)
            );
        } else {
//            wantLockedTotal = wantLockedTotal.add(pairBal.sub(1));
	      wantLockedTotal = wantLockedTotal.add(pairBal).sub(1);

        }
        if (pairBal > 0) {
            IBiswapfarm(masterchef).deposit(pid, pairBal);
        } else {
            IBiswapfarm(masterchef).deposit(pid, 0);
        }
    }

    function withdraw(address _userAddress, uint256 _wantAmt)
        public override
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        uint256 loss = _wantAmt.mul(PLANET_WITHDRAW_FEE).div(PLANET_MAX);

        if (isAfiComp) {
            if (wantAmt < _wantAmt) {
                IBiswapfarm(masterchef).withdraw(pid, _wantAmt.sub(wantAmt));
            } else {
                wantAmt = _wantAmt;
            }
        }
        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        uint256 withdrawalFee = _wantAmt.sub(loss).mul(WITHDRAWAL_FEE).div(
            WITHDRAWAL_MAX
        );
        IERC20(wantAddress).safeTransfer(receiveFee, withdrawalFee);

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }

        sharesTotal = sharesTotal.sub(sharesRemoved);
        wantLockedTotal = wantLockedTotal.sub(_wantAmt);
        IERC20(wantAddress).safeTransfer(
            afiFarmAddress,
            _wantAmt.sub(loss).sub(withdrawalFee)
        );

        return sharesRemoved;
    }

    // 1. Harvest farm tokens
    // 2. Converts farm tokens into want tokens
    // 3. Deposits want tokens

    function earn() public override whenNotPaused {
        require(isAfiComp, "!isAfiComp");
        if (onlyGov) {
            require(msg.sender == govAddress, "Not authorised");
        }

        IBiswapfarm(masterchef).deposit(pid, 0);

        // Converts earn tokens into usdt tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        //earnedAmt = distributeFees(earnedAmt);
        //earnedAmt = buyBack(earnedAmt);
        IBiswapRouter02(unirouterbiswap)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                earnedAmt,
                0,
                earnedToUsdtPath,
                address(this),
                block.timestamp.add(600)
            );
        uint256 usdtBal = IERC20(usdt).balanceOf(address(this));
        usdtBal = distributeFees(usdtBal);
        uint256 buyBackAmt = usdtBal.mul(buyBackRate).div(buyBackRateMax);
//	IERC20(wbnb).safeIncreaseAllowance(uniRouterAddress, buyBackAmt);
	_safeSwap(
            uniRouterAddress,
            buyBackAmt,
            slippageFactor,
            usdtToAFIPath,
            buyBackAddress,
            block.timestamp.add(600)
        );
        

        if (enableAddLiquidity) {
            addLiquidity();
        }

        lastEarnBlock = block.number;

        _farm();
    }

    //Pancakeswap
    function _safeSwap(
        address _uniRouterAddress,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal virtual {
        uint256[] memory amounts = IPancakeRouter02(_uniRouterAddress)
            .getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IPancakeRouter02(_uniRouterAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn,
                amountOut.mul(_slippageFactor).div(1000),
                _path,
                _to,
                _deadline
            );
    }

    /**
     * @dev Swaps {earnedAddress} for {lpToken0}, {lpToken1} & {usdt} using PanearnedAddressSwap.
     */
    function addLiquidity() internal {
        uint256 earnedAddressHalf = IERC20(usdt).balanceOf(address(this)).div(
            2
        );
        //uint256 earnedAddressHalf = _earnedAmt.div(2);

        if (token0Address != usdt) {
            IBiswapRouter02(unirouterbiswap)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    earnedAddressHalf,
                    0,
                    usdtToToken0Path,
                    address(this),
                    now.add(600)
                );
        }

        if (token1Address != usdt) {
            IBiswapRouter02(unirouterbiswap)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    earnedAddressHalf,
                    0,
                    usdtToToken1Path,
                    address(this),
                    now.add(600)
                );
        }

        uint256 lp0Bal = IERC20(token0Address).balanceOf(address(this));
        uint256 lp1Bal = IERC20(token1Address).balanceOf(address(this));
        IBiswapRouter02(unirouterbiswap).addLiquidity(
            token0Address,
            token1Address,
            lp0Bal,
            lp1Bal,
            0,
            0,
            address(this),
            now
        );

        //return IERC20(wantAddress).balanceOf(address(this));
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            buyBackAmt
        );

        IPancakeRouter02(uniRouterAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                buyBackAmt,
                0,
                earnedToAFIPath,
                buyBackAddress,
                now + 60
            );

        return _earnedAmt.sub(buyBackAmt);
    }

    function distributeFees(uint256 _earnedAmt) internal returns (uint256) {
        if (_earnedAmt > 0) {
            // Performance fee
            if (controllerFee > 0) {
                uint256 fee = _earnedAmt.mul(controllerFee).div(
                    controllerFeeMax
                );
                IERC20(usdt).safeTransfer(fundManager, fee.mul(36).div(100));
                IERC20(usdt).safeTransfer(fundManager2, fee.mul(7).div(100));
                IERC20(usdt).safeTransfer(fundManager3, fee.mul(3).div(100));
                IERC20(usdt).safeTransfer(receiveFee, fee.mul(54).div(100));
                _earnedAmt = _earnedAmt.sub(fee);
            }
        }

        return _earnedAmt;
    }

    function convertDustToEarned() public whenNotPaused {
        require(isAfiComp, "!isAfiComp");
        require(!isCAKEStaking, "isCAKEStaking");

        // Converts dust tokens into earned tokens, which will be reinvested on the next earn().

        // Converts token0 dust (if any) to earned tokens
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        if (token0Address != earnedAddress && token0Amt > 0) {
            IERC20(token0Address).safeIncreaseAllowance(
                unirouterbiswap,
                token0Amt
            );

            // Swap all dust tokens to earned tokens
            IBiswapRouter02(unirouterbiswap)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    token0Amt,
                    0,
                    token0ToEarnedPath,
                    address(this),
                    now + 60
                );
        }

        // Converts token1 dust (if any) to earned tokens
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token1Address != earnedAddress && token1Amt > 0) {
            IERC20(token1Address).safeIncreaseAllowance(
                unirouterbiswap,
                token1Amt
            );

            // Swap all dust tokens to earned tokens
            IBiswapRouter02(unirouterbiswap)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    token1Amt,
                    0,
                    token1ToEarnedPath,
                    address(this),
                    now + 60
                );
        }
    }

    function pause() public override {
        require(msg.sender == govAddress, "!gov");
        _pause();
        IERC20(wantAddress).safeApprove(masterchef, 0);
        IERC20(earnedAddress).safeApprove(unirouterbiswap, 0);
        IERC20(usdt).safeApprove(unirouterbiswap, 0);
        IERC20(token0Address).safeApprove(unirouterbiswap, 0);
        IERC20(token1Address).safeApprove(unirouterbiswap, 0);
    }

    function unpause() external override {
        require(msg.sender == govAddress, "!gov");
        _unpause();
        IERC20(wantAddress).safeApprove(masterchef, uint256(-1));
        IERC20(earnedAddress).safeApprove(unirouterbiswap, uint256(-1));
        IERC20(usdt).safeApprove(unirouterbiswap, uint256(-1));

        IERC20(token0Address).safeApprove(unirouterbiswap, 0);
        IERC20(token0Address).safeApprove(unirouterbiswap, uint256(-1));

        IERC20(token1Address).safeApprove(unirouterbiswap, 0);
        IERC20(token1Address).safeApprove(unirouterbiswap, uint256(-1));
    }

    function setEnableAddLiquidity(bool _status) public override {
        require(msg.sender == govAddress, "!gov");
        enableAddLiquidity = _status;
    }

    function setWITHDRAWALFee(uint256 _WITHDRAWAL_FEE) public override {
        require(msg.sender == govAddress, "!gov");
        WITHDRAWAL_FEE = _WITHDRAWAL_FEE;
    }

    function setControllerFee(uint256 _controllerFee) public override {
        require(msg.sender == govAddress, "!gov");
        require(_controllerFee <= controllerFeeUL, "too high");
        controllerFee = _controllerFee;
    }

    function setbuyBackRate(uint256 _buyBackRate) public override {
        require(msg.sender == govAddress, "!gov");
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setReceieveFeeAddress(address _receiveFeeAddress) public override {
        require(msg.sender == govAddress, "!gov");
        receiveFee = _receiveFeeAddress;
    }

    function setGov(address _govAddress) public override {
        require(msg.sender == govAddress, "!gov");
        govAddress = _govAddress;
    }

    function setOnlyGov(bool _onlyGov) public override {
        require(msg.sender == govAddress, "!gov");
        onlyGov = _onlyGov;
    }

    function setfundManager(address _fundManager) public override {
        require(msg.sender == govAddress, "!gov");
        fundManager = _fundManager;
    }

    function setfundManager2(address _fundManager2) public override {
        require(msg.sender == govAddress, "!gov");
        fundManager2 = _fundManager2;
    }

    function setfundManager3(address _fundManager3) public override {
        require(msg.sender == govAddress, "!gov");
        fundManager3 = _fundManager3;
    }

}