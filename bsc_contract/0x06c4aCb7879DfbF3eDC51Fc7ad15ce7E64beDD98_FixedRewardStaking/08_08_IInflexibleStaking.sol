// SPDX-License-Identifier: None
pragma solidity ^0.8.9;

interface IInflexibleStaking {
    function pendingReward(address _user) external view returns (uint256);

    function stake(uint256 _amount) external;

    function unstake() external;

    function emergencyWithdraw() external;

    event Stake(address indexed user, uint256 amount);

    event Unstake(address indexed user, uint256 amount);
}