// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IFreezingStaking {
    function stake(uint256 _amount, uint _period) external;
    function unStake() external;
}