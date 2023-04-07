// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

interface ILaunchpadSimpleDelegate {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function claim() external;
}