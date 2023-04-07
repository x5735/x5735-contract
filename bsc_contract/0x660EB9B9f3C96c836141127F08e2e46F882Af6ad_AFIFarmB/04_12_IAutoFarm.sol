// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAutoFarm {
    function add(
        uint256 _allocPoint,
        address _want,
        bool _withUpdate,
        address _strat
    ) external; // owner only

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external; // owner only

    function setAFIPerBlock(uint256 _inputAmt) external; // owner only

    function transferFarmOwnership(address _newOwner) external; // owner only
}