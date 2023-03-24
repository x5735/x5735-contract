//SPDX-License-Identifier: UXUY
pragma solidity ^0.8.11;

interface IProtocol {
    struct SwapParams {
        bytes4 providerID;
        address[] path;
        uint minAmountOut;
        bytes data;
    }

    struct BridgeParams {
        bytes4 providerID;
        address tokenIn;
        uint chainIDOut;
        address tokenOut;
        uint minAmountOut;
        bytes data;
    }

    struct TradeParams {
        uint amountIn;
        SwapParams[] swaps;
        BridgeParams bridge;
        address recipient;
        address feeShareRecipient;
        uint extraFeeAmountIn; // Extra fee deducted to pay the gas fee
        SwapParams[] extraFeeSwaps;
        uint deadline;
    }

    // @dev Emitted when fee rate is updated by owner
    event FeeRateChanged(uint feeRate, uint feeShareRate);

    // @dev Emitted when trade is executed
    event Traded(
        address indexed sender,
        address indexed recipient,
        address indexed feeShareRecipient,
        address tokenIn,
        uint amountIn,
        uint chainIDOut,
        address tokenOut,
        uint amountOut,
        uint bridgeTxnID,
        address feeToken,
        uint amountFee,
        uint amountFeeShare,
        uint amountExtraFee
    );

    // @dev gets the swap contract
    function swapContract() external view returns (address);

    // @dev gets the bridge contract
    function bridgeContract() external view returns (address);

    // @dev gets the fee denominator
    function feeDenominator() external pure returns (uint);

    // @dev gets the total fee rate
    function feeRate() external view returns (uint);

    // @dev gets the fee share rate
    function feeShareRate() external view returns (uint);

    // @dev trade between tokens
    function trade(TradeParams calldata params) external payable returns (uint amountOut, uint bridgeTxnID);
}