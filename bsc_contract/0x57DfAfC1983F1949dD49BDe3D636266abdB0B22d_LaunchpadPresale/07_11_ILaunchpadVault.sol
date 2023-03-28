// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

interface ILaunchpadVault {
    function currentUserInfoAt(address addr, uint256 index) external view returns (uint256);

    function increasePeggedAmount(address addr, uint256 amount) external returns (uint256);

    function decreasePeggedAmount(address addr, uint256 amount) external returns (uint256);
}