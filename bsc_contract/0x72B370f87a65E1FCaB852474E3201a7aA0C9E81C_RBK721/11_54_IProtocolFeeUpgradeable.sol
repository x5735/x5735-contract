// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IProtocolFeeUpgradeable {
    /**
     * @dev Fee information structure
     */
    struct FeeInfo {
        address token;
        uint96 royalty;
    }

    event ProtocolFeeUpdated(
        address indexed operator,
        address indexed payment,
        uint256 indexed royalty
    );

    function setRoyalty(address token_, uint96 feeAmt_) external;
}