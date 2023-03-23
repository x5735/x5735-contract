// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/OpenLevInterface.sol";
import "../IOPBorrowing.sol";
import "../OPBorrowingLib.sol";

contract DAppHelper {
    uint internal constant RATIO_DENOMINATOR = 10000;

    constructor() {}

    struct BorrowerInfoVars {
        uint256 balanceOfColl;
        uint256 collateral;
        uint256 collateralAmount;
        uint256 borrowing;
        uint256 collateralRatio;
    }

    struct PoolInfoVars {
        uint256 availableForBorrow;
        uint256 availableForLimit;
    }

    function getBorrowerInfo(
        IOPBorrowing borrowing,
        address borrower,
        uint16[] calldata marketIds,
        bool[] calldata collateralIndexes
    ) external view returns (BorrowerInfoVars[] memory results) {
        results = new BorrowerInfoVars[](marketIds.length);
        for (uint i = 0; i < marketIds.length; i++) {
            BorrowerInfoVars memory result;
            result.collateral = OPBorrowingStorage(address(borrowing)).activeCollaterals(borrower, marketIds[i], collateralIndexes[i]);
            (LPoolInterface pool0, LPoolInterface pool1, address token0, address token1,) = OPBorrowingStorage(address(borrowing)).markets(marketIds[i]);
            address collToken = collateralIndexes[i] ? token1 : token0;
            result.balanceOfColl = IERC20(collToken).balanceOf(borrower);
            if (result.collateral > 0) {
                {
                    address borrowingAddr = address(borrowing);
                    result.collateralAmount = OPBorrowingLib.shareToAmount(
                        result.collateral,
                        OPBorrowingStorage(borrowingAddr).totalShares(collToken),
                        IERC20(collToken).balanceOf(borrowingAddr)
                    );
                }
                address _borrower = borrower;
                result.borrowing = (collateralIndexes[i] ? pool0 : pool1).borrowBalanceCurrent(_borrower);
                result.collateralRatio = borrowing.collateralRatio(marketIds[i], collateralIndexes[i], _borrower);
            }
            results[i] = result;
        }
    }

    function getPoolsAvailable(
        IOPBorrowing borrowing,
        DexAggregatorInterface dexAgg,
        uint16[] calldata marketIds,
        bool[] calldata collIndexes,
        address[] calldata borrowPools
    ) external view returns (PoolInfoVars[] memory results) {
        results = new PoolInfoVars[](marketIds.length);
        for (uint i = 0; i < marketIds.length; i++) {
            PoolInfoVars memory result;
            OPBorrowingStorage borrowingStorage = OPBorrowingStorage(address(borrowing));
            uint16 marketId = marketIds[i];
            uint realTimeLiq;
            {
                (,, address token0, address token1, uint32 dex) = borrowingStorage.markets(marketId);
                realTimeLiq = dexAgg.getToken0Liquidity(collIndexes[i] ? token0 : token1, collIndexes[i] ? token1 : token0, uint32ToBytes(dex));
            }
            uint twaLiq;
            {
                (uint twaL0,uint twaL1) = borrowingStorage.twaLiquidity(marketId);
                twaLiq = collIndexes[i] ? twaL0 : twaL1;
            }
            (,uint16 maxLiquidityRatio,,,,,,,,,) = borrowingStorage.marketsConf(marketId);
            result.availableForBorrow = IPool(borrowPools[i]).availableForBorrow();

            uint borrowLimit = minOf(twaLiq, realTimeLiq) * (maxLiquidityRatio) / (RATIO_DENOMINATOR);
            uint totalBorrows = IPool(borrowPools[i]).totalBorrowsCurrent();
            if (totalBorrows < borrowLimit) {
                result.availableForLimit = borrowLimit - totalBorrows;
            }
            results[i] = result;
        }
    }


    function minOf(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    function shareToAmount(uint share, uint totalShare, uint reserve) internal pure returns (uint amount) {
        if (totalShare > 0 && reserve > 0) {
            amount = (reserve * share) / totalShare;
        }
    }

    function uint32ToBytes(uint32 u) internal pure returns (bytes memory) {
        if (u < 256) {
            return abi.encodePacked(uint8(u));
        }
        return abi.encodePacked(u);
    }
}

interface IPool {
    function availableForBorrow() external view returns (uint);
    function totalBorrowsCurrent() external view returns (uint);
}