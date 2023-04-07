// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IFSPPool {
    function initialize(
        address _stakedToken,
        address _reflectionToken,
        uint256 _rewardSupply,
        uint256 _APYPercent,
        uint256 _lockTimeType,
        uint256 _limitAmountPerUser,
        bool _isPartition,
        bool _isPrivate
    ) external;

    function setFSPFactory (address _fspFactory) external;

    function transferOwnership(address _newOwner) external;

}