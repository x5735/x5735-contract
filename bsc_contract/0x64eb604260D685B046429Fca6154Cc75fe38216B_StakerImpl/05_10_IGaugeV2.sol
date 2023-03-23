// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IGaugeV2 {
    function rewardToken() external returns(address);

    ///@notice deposit all TOKEN of msg.sender
    function depositAll() external;

    ///@notice deposit amount TOKEN
    function deposit(uint256 amount) external;

    ///@notice withdraw all token
    function withdrawAll() external;
    
    ///@notice withdraw all TOKEN and harvest rewardToken
    function withdrawAllAndHarvest() external;

    ///@notice User harvest function
    function getReward() external;
}