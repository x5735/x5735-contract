// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargateFactory {
    function getPool(uint256 poolId) external view returns (address);

    function allPools(uint256 index) external view returns (address);

    function allPoolsLength() external view returns (uint256);
}