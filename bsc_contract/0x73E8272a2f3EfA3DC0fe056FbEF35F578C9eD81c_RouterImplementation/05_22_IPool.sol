// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;


import '../token/IDToken.sol';

interface IPool {

    function implementation() external view returns (address);

    function protocolFeeCollector() external view returns (address);

    function liquidity() external view returns (int256);

    function lpsPnl() external view returns (int256);

    function cumulativePnlPerLiquidity() external view returns (int256);

    function protocolFeeAccrued() external view returns (int256);

    function setImplementation(address newImplementation) external;

    function addMarket(address market) external;

    function approveSwapper(address underlying) external;

    function collectProtocolFee() external;

    function setRouter(address, bool) external;

    function claimVenusLp(address account) external;

    function claimVenusTrader(address account) external;

    struct OracleSignature {
        bytes32 oracleSymbolId;
        uint256 timestamp;
        uint256 value;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function addLiquidity(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external payable;

    function removeLiquidity(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external;

    function addMargin(address account, address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external payable;

    function removeMargin(address account, address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external;

    // @tradeParams
    //  futures/option/power:   [tradeVolume, priceLimit]
    //  gamma:                  [tradeVolume, entryPrice, powerPriceLimit, futuresPriceLimit]
    function trade(
        address account,
        string memory symbolName,
        int256[] memory tradeParams
    ) external;

    function liquidate(uint256 pTokenId, OracleSignature[] memory oracleSignatures) external;

    struct LpInfo {
        address vault;
        int256 amountB0;
        int256 liquidity;
        int256 cumulativePnlPerLiquidity;
    }

    function lpInfos(uint256) external view returns (LpInfo memory);

    function tokenB0() external view returns (address);

    function vTokenB0() external view returns (address);

    function minRatioB0() external view returns (int256);

    function lToken() external view returns (IDToken);

    function pToken() external view returns (IDToken);

    function decimalsB0() external view returns (uint256);

}