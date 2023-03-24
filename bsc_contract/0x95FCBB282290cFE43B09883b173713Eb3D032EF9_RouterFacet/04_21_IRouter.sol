//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "../libraries/LibRouter.sol";

interface IRouter {
    enum TargetAction {Unlock, Mint}

    struct DeliveryFeeData {
        // fee amount
        uint256 fee;
        // block after which the signature should be considered invalid
        uint256 expiry;
        // the delivery agent's signature
        bytes signature;
    }

    /// @notice An event emitted once a Lock transaction is executed
    event LockMint(uint8 targetChain, address token, uint256 amount, bytes receiver);
    /// @notice An event emitted once a Burn transaction is executed
    event BurnMint(uint8 targetChain, address token, uint256 amount, bytes receiver);
    /// @notice An event emitted once a BurnAndTransfer transaction is executed
    event BurnUnlock(uint8 targetChain, address token, uint256 amount, bytes receiver);
    /// @notice An event emitted once an Unlock transaction is executed
    event Unlock(address token, uint256 amount, address receiver);
    /// @notice An even emitted once a Mint transaction is executed
    event Mint(address token, uint256 amount, address receiver);
    /// @notice An event emitted once a new wrapped token is deployed by the contract
    event WrappedTokenDeployed(uint8 sourceChain, bytes nativeToken, address wrappedToken);
    /// @notice An event emitted when setting the teleport address
    event TeleportSet(address teleport);
    /// @notice An event emitted when delivery fee has been transfered to the delivery agent
    event DeliveryFeeCollected(address user, address agent, uint256 amount);
    /// @notice An event emitted when fees are paid in custom token
    event FeeTokensCollected(address feeToken, address user, address collector, uint256 amount);


    function nativeToWrappedToken(uint8 chainId_, bytes memory nativeToken_) external view returns (address);
    function wrappedToNativeToken(address wrappedToken_) external view returns (LibRouter.NativeTokenWithChainId memory);
    function serviceFee() external view returns (uint256);
    function deliveryFeeNonce(address sender_) external view returns (uint256);

    function egress(
        uint8 targetChain_,
        address feeToken_,
        address token_,
        uint256 amount_,
        bytes calldata receiver_,
        DeliveryFeeData calldata deliveryFeeData_) external payable;

    function egressWithPermit(
        uint8 targetChain_,
        address feeToken_,
        address token_,
        uint256 amount_,
        bytes calldata receiver_,
        DeliveryFeeData calldata deliveryFeeData_,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s) external payable;

}