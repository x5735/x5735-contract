// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IBaseStaking {
    function stake(uint256 _amount) external;
    function unStake() external;
}