// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

interface ILaunchpadPooledDelegate {
    function deposit(uint256 pid, uint256 amount) external;
    
    function withdraw(uint256 pid, uint256 amount) external;

    function claim(uint256 pid) external;
}