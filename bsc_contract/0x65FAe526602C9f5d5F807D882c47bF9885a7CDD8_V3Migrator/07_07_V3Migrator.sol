// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import '../interfaces/IBiswapPair.sol';
import '../interfaces/ILiquidityManager.sol';
import '../interfaces/IV3Migrator.sol';

import './base/base.sol';

/// @title Biswap V3 Migrator
contract V3Migrator is Base, IV3Migrator {

    address public immutable liquidityManager;

    constructor(
        address _factory,
        address _WETH9,
        address _liquidityManager
    ) Base(_factory, _WETH9) {
        liquidityManager = _liquidityManager;
    }

    function migrate(MigrateParams calldata params) external override {
        require(params.percentageToMigrate > 0, 'Percentage too small');
        require(params.percentageToMigrate <= 100, 'Percentage too large');

        // burn v2 liquidity to this address
        IBiswapPair(params.pair).transferFrom(msg.sender, params.pair, params.liquidityToMigrate);
        (uint256 amount0V2, uint256 amount1V2) = IBiswapPair(params.pair).burn(address(this));

        // calculate the amounts to migrate to v3
        uint128 amount0V2ToMigrate = uint128(amount0V2 * params.percentageToMigrate / 100);
        uint128 amount1V2ToMigrate = uint128(amount1V2 * params.percentageToMigrate / 100);

        // approve the position manager up to the maximum token amounts
        safeApprove(params.token0, liquidityManager, amount0V2ToMigrate);
        safeApprove(params.token1, liquidityManager, amount1V2ToMigrate);

        // mint v3 position
        (, , uint256 amount0V3, uint256 amount1V3) = ILiquidityManager(liquidityManager).mint(
            ILiquidityManager.MintParam({
                miner: params.recipient,
                tokenX: params.token0,
                tokenY: params.token1,
                fee: params.fee,
                pl: params.tickLower,
                pr: params.tickUpper,
                xLim: amount0V2ToMigrate,
                yLim: amount1V2ToMigrate,
                amountXMin: params.amount0Min,
                amountYMin: params.amount1Min,
                deadline: params.deadline
            })
        );

        // if necessary, clear allowance and refund dust
        if (amount0V3 < amount0V2) {
            if (amount0V3 < amount0V2ToMigrate) {
                safeApprove(params.token0, liquidityManager, 0);
            }

            uint256 refund0 = amount0V2 - amount0V3;
            if (params.refundAsETH && params.token0 == WETH9) {
                IWETH9(WETH9).withdraw(refund0);
                safeTransferETH(msg.sender, refund0);
            } else {
                safeTransfer(params.token0, msg.sender, refund0);
            }
        }
        if (amount1V3 < amount1V2) {
            if (amount1V3 < amount1V2ToMigrate) {
                safeApprove(params.token1, liquidityManager, 0);
            }

            uint256 refund1 = amount1V2 - amount1V3;
            if (params.refundAsETH && params.token1 == WETH9) {
                IWETH9(WETH9).withdraw(refund1);
                safeTransferETH(msg.sender, refund1);
            } else {
                safeTransfer(params.token1, msg.sender, refund1);
            }
        }
    }
}