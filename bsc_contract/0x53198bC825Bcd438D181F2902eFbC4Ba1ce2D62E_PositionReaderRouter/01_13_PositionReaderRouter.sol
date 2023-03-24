// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/interfaces/IBasePositionManager.sol";
import "../core/VaultMSData.sol";

interface IVaultTarget {
    function vaultUtils() external view returns (address);
}

struct DispPosition {
    address account;
    address collateralToken;
    address indexToken;
    uint256 size;
    uint256 collateral;
    uint256 averagePrice;
    uint256 reserveAmount;
    uint256 lastUpdateTime;
    uint256 aveIncreaseTime;

    uint256 entryFundingRateSec;
    int256 entryPremiumRateSec;

    int256 realisedPnl;

    uint256 stopLossRatio;
    uint256 takeProfitRatio;

    bool isLong;

    bytes32 key;
    uint256 delta;
    bool hasProfit;

    int256 accPremiumFee;
    uint256 accFundingFee;
    uint256 accPositionFee;
    uint256 accCollateral;

    int256 pendingPremiumFee;
    uint256 pendingPositionFee;
    uint256 pendingFundingFee;

    uint256 indexTokenMinPrice;
    uint256 indexTokenMaxPrice;
}


struct DispToken {
    address token;

    //tokenBase part
    bool isFundable;
    bool isStable;
    uint256 decimal;
    uint256 weight;         
    uint256 maxUSDAmounts;  // maxUSDAmounts allows setting a max amount of USDX debt for a token
    uint256 balance;        // tokenBalances is used only to determine _transferIn values
    uint256 poolAmount;     // poolAmounts tracks the number of received tokens that can be used for leverage
    uint256 poolSize;
    uint256 reservedAmount; // reservedAmounts tracks the number of tokens reserved for open leverage positions
    uint256 bufferAmount;   // bufferAmounts allows specification of an amount to exclude from swaps
                            // this can be used to ensure a certain amount of liquidity is available for leverage positions
    uint256 guaranteedUsd;  // guaranteedUsd tracks the amount of USD that is "guaranteed" by opened leverage positions

    //trec part
    uint256 shortSize;
    uint256 shortCollateral;
    uint256 shortAveragePrice;
    uint256 longSize;
    uint256 longCollateral;
    uint256 longAveragePrice;

    //fee part
    uint256 fundingRatePerSec; //borrow fee & token util
    uint256 fundingRatePerHour; //borrow fee & token util
    uint256 accumulativefundingRateSec;

    int256 longRatePerSec;  //according to position
    int256 shortRatePerSec; //according to position
    int256 longRatePerHour;  //according to position
    int256 shortRatePerHour; //according to position

    int256 accumulativeLongRateSec;
    int256 accumulativeShortRateSec;
    uint256 latestUpdateTime;

    //limit part
    uint256 maxShortSize;
    uint256 maxLongSize;
    uint256 maxTradingSize;
    uint256 maxRatio;
    uint256 countMinSize;

    //
    uint256 spreadBasis;
    uint256 maxSpreadBasis;// = 5000000 * PRICE_PRECISION;
    uint256 minSpreadCalUSD;// = 10000 * PRICE_PRECISION;

}

struct GlobalFeeSetting{
    uint256 taxBasisPoints; // 0.5%
    uint256 stableTaxBasisPoints; // 0.2%
    uint256 mintBurnFeeBasisPoints; // 0.3%
    uint256 swapFeeBasisPoints; // 0.3%
    uint256 stableSwapFeeBasisPoints; // 0.04%
    uint256 marginFeeBasisPoints; // 0.1%
    uint256 liquidationFeeUsd;
    uint256 maxLeverage; // 100x
    //Fees related to funding
    uint256 fundingRateFactor;
    uint256 stableFundingRateFactor;
    //trading tax part
    uint256 taxGradient;
    uint256 taxDuration;
    uint256 taxMax;
    //trading profit limitation part
    uint256 maxProfitRatio;
    uint256 premiumBasisPointsPerHour;
    int256 posIndexMaxPointsPerHour;
    int256 negIndexMaxPointsPerHour;
}

interface PositionReaderIntf{
    function getUserPositions(address _vault, address _account) external view returns (DispPosition[] memory);
    function getTokenInfo(address _vault, address[] memory _fundTokens) external view returns (DispToken[] memory);
    function getGlobalFeeInfo(address _vault) external view returns (GlobalFeeSetting memory);
}


contract PositionReaderRouter is Ownable {
    mapping(address => bool) public isOldVersion;
    address public preV_positionReader;
    address public newV_positionReader;

    function setOldVersion(address _vault, bool _status) external onlyOwner{
        isOldVersion[_vault] = _status;
    }

    function setPositionReader(address _pre_v, address _new_v) external onlyOwner{
        preV_positionReader = _pre_v;
        newV_positionReader = _new_v;
    }

    function getUserPositions(address _vault, address _account) external view returns (DispPosition[] memory){
        if (isOldVersion[_vault])
            return PositionReaderIntf(preV_positionReader).getUserPositions(_vault,  _account);
        else
            return PositionReaderIntf(newV_positionReader).getUserPositions(_vault,  _account);
    }


    function getTokenInfo(address _vault, address[] memory _fundTokens) external view returns (DispToken[] memory) {
        if (isOldVersion[_vault])
            return PositionReaderIntf(preV_positionReader).getTokenInfo(_vault,  _fundTokens);
        else
            return PositionReaderIntf(newV_positionReader).getTokenInfo(_vault,  _fundTokens);
    }

    function getGlobalFeeInfo(address _vault) external view returns (GlobalFeeSetting memory){//Fees related to swap
        if (isOldVersion[_vault])
            return PositionReaderIntf(preV_positionReader).getGlobalFeeInfo(_vault);
        else
            return PositionReaderIntf(newV_positionReader).getGlobalFeeInfo(_vault);     
    }
}