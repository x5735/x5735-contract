// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargatePool {
    function poolId() external view returns (uint256);

    function token() external view returns (address);
}