// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "./Extension/ILaunchpadVault.sol";

interface ILaunchpadCore is ILaunchpadVault {
    function startFactory() external;

    function closeFactory() external;

    function suspend() external;

    function restore() external;

    function deposit(uint256 baseAmount, uint256 pairAmount, uint256 timestamp) external payable;

    function defaultRelease() external payable;

    function instantRelease() external payable;

    function defaultWithdraw() external payable;

    function instantWithdraw() external payable;

    function releaseFor(address addr) external;

    function withdrawFor(address addr) external;
}