//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

interface ITeleportDApp {
    /**
     * @notice Called by a Teleport contract to deliver a verified payload to a dApp
     * @param _sourceChainId The Abridge chainID where the transmission originated
     * @param _transmissionSender The address that invoked `transmit()` on the source chain
     * @param _dAppId an identifier for the dApp
     * @param _payload a dApp-specific byte array with the message data
     */
    function onTeleportMessage(
        uint8 _sourceChainId,
        bytes calldata _transmissionSender,
        bytes32 _dAppId,
        bytes calldata _payload) external;
}