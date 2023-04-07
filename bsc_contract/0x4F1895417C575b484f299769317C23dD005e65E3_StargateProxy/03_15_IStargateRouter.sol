// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargateRouter {
    event Revert(uint8 bridgeFunctionType, uint16 chainId, bytes srcAddress, uint256 nonce);
    event CachedSwapSaved(
        uint16 chainId,
        bytes srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        address to,
        bytes payload,
        bytes reason
    );
    event RevertRedeemLocal(
        uint16 srcChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        bytes to,
        uint256 redeemAmountSD,
        uint256 mintAmountSD,
        uint256 indexed nonce,
        bytes indexed srcAddress
    );
    event RedeemLocalCallback(
        uint16 srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address to,
        uint256 amountSD,
        uint256 mintAmountSD
    );

    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function factory() external view returns (address);

    function bridge() external view returns (address);

    function revertLookup(
        uint16 chainId,
        bytes calldata srcAddress,
        uint256 nonce
    ) external view returns (bytes memory);

    function cachedSwapLookup(
        uint16 chainId,
        bytes calldata srcAddress,
        uint256 nonce
    )
        external
        view
        returns (
            address token,
            uint256 amountLD,
            address to,
            bytes calldata payload
        );

    function addLiquidity(
        uint256 _poolId,
        uint256 _amountLD,
        address _to
    ) external;

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external returns (uint256);

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function sendCredits(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress
    ) external payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);

    function revertRedeemLocal(
        uint16 _dstChainId,
        bytes calldata _srcAddress,
        uint256 _nonce,
        address payable _refundAddress,
        lzTxObj memory _lzTxParams
    ) external payable;

    function retryRevert(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint256 _nonce
    ) external payable;

    function clearCachedSwap(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint256 _nonce
    ) external;
}