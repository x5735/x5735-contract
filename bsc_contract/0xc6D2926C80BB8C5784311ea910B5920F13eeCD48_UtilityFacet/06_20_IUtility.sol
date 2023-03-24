// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

interface IUtility {

    struct Subroutine {
        address contractAddress;
        bytes callParams;
    }

    struct TeleportSender {
        // The Abridge  chain id for the sender
        uint8 chainId;
        // The actual sender address
        bytes senderAddress;
    }

    enum TokenAction {Pause, Unpause}

    function pauseToken(address tokenAddress_, bytes[] calldata signatures_) external;
    function unpauseToken(address tokenAddress_, bytes[] calldata signatures_) external;

    function setWrappedToken(
        uint8 nativeChainId_, bytes calldata _nativeToken, address wrappedToken_, bytes[] calldata signatures_
    ) external;
    function unsetWrappedToken(address wrappedToken_, bytes[] calldata signatures_) external;

    function setTeleportSenders(TeleportSender[] calldata senders_, bytes[] calldata signatures_) external;

    function dappId() external view returns (bytes32);
    function setDappId(bytes32 dappId_, bytes[] calldata signatures_) external;

    function setFeeToken(address feeToken_, uint256 amount_, bytes[] calldata signatures_) external;
    function feeAmountByToken(address feeToken_) external view returns(uint256);
    function feeTokens() external view returns(address[] memory);

    function feeTokenCollector() external view returns (address);
    function setFeeTokenCollector(address feeTokenCollector_, bytes[] calldata signatures_) external;

    function deliveryAgent() external view returns (address);
    function setDeliveryAgent(address deliveryAgent_, bytes[] calldata signatures_) external;

    event TokenPaused(address account_, address token_);
    event TokenUnpaused(address account_, address token_);
    event WrappedTokenSet(uint8 nativeChainId_, bytes _nativeToken, address wrappedToken_);
    event WrappedTokenUnset(address wrappedToken_);
    event TeleportSenderSet(TeleportSender[] senders_);
    event DappIdSet(bytes32 dappId_);
    event FeeTokenSet(address feeToken_, uint256 amount_);
    event FeeTokenCollectorSet(address feeTokenCollector_);
    event DeliveryAgentSet(address deliveryAgent_);

}