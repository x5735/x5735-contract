//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

interface ITeleport {
    /// @notice emitted when transmitting a payload
    event Transmission(bytes transmissionSender, uint8 targetChainId, bytes transmissionReceiver, bytes32 dAppId, bytes payload);
    /// @notice emitted when collecting fees
    event TransmissionFees(uint256 serviceFee);
    /// @notice emitted when delivering a payload
    event Delivery(bytes32 transmissionId);

    /// @return The currently set service fee
    function serviceFee() external view returns (uint256);

    function transmit(
        uint8 targetChainId,
        bytes calldata transmissionReceiver,
        bytes32 dAppId,
        bytes calldata payload
    ) external payable;

    function deliver(
        bytes32 transmissionId,
        uint8 sourceChainId,
        bytes calldata transmissionSender,
        address transmissionReceiver,
        bytes32 dAppId,
        bytes calldata payload,
        bytes[] calldata signatures
    ) external;
}