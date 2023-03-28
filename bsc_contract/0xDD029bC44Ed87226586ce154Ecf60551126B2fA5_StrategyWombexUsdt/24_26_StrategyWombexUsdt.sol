// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../Strategy.sol";
import "../connectors/Chainlink.sol";
import "../connectors/Wombex.sol";
import "../connectors/PancakeV2.sol";
import "../libraries/TokenMath.sol";
import {IWombatRouter, WombatLibrary} from '../connectors/Wombat.sol';


contract StrategyWombexUsdt is Strategy {

    // --- structs

    struct StrategyParams {
        address usdt;
        address wom;
        address wmx;
        address lpUsdt;
        address wmxLpUsdt;
        address poolDepositor;
        address pool;
        address pancakeRouter;
        address wombatRouter;
        address oracleUsdt;
    }

    // --- params

    IERC20 public usdt;
    IERC20 public wom;
    IERC20 public wmx;

    IAsset public lpUsdt;
    IBaseRewardPool public wmxLpUsdt;
    IPoolDepositor public poolDepositor;
    IPool public pool;

    IPancakeRouter02 public pancakeRouter;
    IWombatRouter public wombatRouter;

    IPriceFeed public oracleBusd;
    IPriceFeed public oracleUsdt;

    uint256 public usdtDm;
    uint256 public lpUsdtDm;

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdt = IERC20(params.usdt);
        wom = IERC20(params.wom);
        wmx = IERC20(params.wmx);

        lpUsdt = IAsset(params.lpUsdt);
        wmxLpUsdt = IBaseRewardPool(params.wmxLpUsdt);
        poolDepositor = IPoolDepositor(params.poolDepositor);
        pool = IPool(lpUsdt.pool());

        pancakeRouter = IPancakeRouter02(params.pancakeRouter);
        wombatRouter = IWombatRouter(params.wombatRouter);

        oracleUsdt = IPriceFeed(params.oracleUsdt);

        usdtDm = 10 ** IERC20Metadata(params.usdt).decimals();
        lpUsdtDm = 10 ** IERC20Metadata(params.lpUsdt).decimals();

        usdt.approve(address(poolDepositor), type(uint256).max);
        wmxLpUsdt.approve(address(poolDepositor), type(uint256).max);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

     //   require(_asset == address(usdt), "Some token not compatible");

        // get potential deposit amount
        uint256 usdtBalance = usdt.balanceOf(address(this));
        (uint256 lpUsdtAmount,) = poolDepositor.getDepositAmountOut(address(lpUsdt), usdtBalance);
        // deposit
        //console.log('wombextusdt usdtBalance: %s address: %s',usdtBalance,address(lpUsdt));
        poolDepositor.deposit(address(lpUsdt), usdtBalance, OvnMath.subBasisPoints(lpUsdtAmount, stakeSlippageBP), true);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

       require(_asset == address(usdt), "Some token not compatible");

        // get withdraw amount for 1 LP
        (uint256 usdtAmountOneAsset,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtDm);
        // add 1bp for smooth withdraw
        uint256 lpUsdtAmount = OvnMath.addBasisPoints(_amount, stakeSlippageBP) * lpUsdtDm / usdtAmountOneAsset;

        // withdraw
        wmxLpUsdt.approve(address(poolDepositor), lpUsdtAmount);
        poolDepositor.withdraw(address(lpUsdt), lpUsdtAmount, _amount, address(this));

        return usdt.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

      require(_asset == address(usdt), "Some token not compatible");

        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            // get withdraw amount
            (uint256 usdtAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtBalance);
            // withdraw
            wmxLpUsdt.approve(address(poolDepositor), lpUsdtBalance);
            poolDepositor.withdraw(address(lpUsdt), lpUsdtBalance, OvnMath.subBasisPoints(usdtAmount, stakeSlippageBP), address(this));
        }

        return usdt.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdtBalance = usdt.balanceOf(address(this));

        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            (uint256 usdtAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtBalance);
            usdtBalance += usdtAmount;
        }

        return usdtBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            wmxLpUsdt.getReward(address(this), false);
        }

        // sell rewards
        uint256 totalUsdt;

        uint256 womBalance = wom.balanceOf(address(this));
        if (womBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wom),
                address(usdt),
                womBalance
            );

            if (amountOut > 0) {
                uint256 womBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wom),
                    address(usdt),
                    womBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalUsdt += womBusd;
            }
        }

        uint256 wmxBalance = wmx.balanceOf(address(this));
        if (wmxBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wmx),
                address(usdt),
                wmxBalance
            );

            if (amountOut > 0) {
                uint256 wmxBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wmx),
                    address(usdt),
                    wmxBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalUsdt += wmxBusd;
            }
        }

        if (totalUsdt > 0) {
            usdt.transfer(_to, totalUsdt);
        }

        return totalUsdt;
    }

}