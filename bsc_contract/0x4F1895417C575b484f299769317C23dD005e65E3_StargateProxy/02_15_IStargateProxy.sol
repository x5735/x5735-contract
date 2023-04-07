// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargateProxy {
    error SwapFailure(bytes reason);
    error DstChainNotFound(uint16 chainId);
    error PoolNotFound(uint256 poolId);
    error Forbidden();
    error InvalidPayload();

    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event CallFailure(address indexed srcFrom, address indexed to, bytes data, bytes reason);
    event SGReceive(
        uint16 indexed srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        address token,
        uint256 amountLD
    );

    struct TransferParams {
        address swapTo;
        bytes swapData;
        uint256 poolId;
        uint256 amount;
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 dstMinAmount;
        address dstCallTo;
        bytes dstCallData;
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
    }

    function estimateFee(
        uint16 dstChainId,
        address dstCallTo,
        bytes calldata dstCallData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256);

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external;

    function transferNative(uint256 amount, TransferParams calldata params) external payable;

    function transferERC20(
        address token,
        uint256 amount,
        TransferParams calldata params
    ) external payable;
}