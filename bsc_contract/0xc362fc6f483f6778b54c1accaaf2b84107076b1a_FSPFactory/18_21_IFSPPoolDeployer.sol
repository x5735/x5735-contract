// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IFSPPoolDeployer {

    function createPool(bytes32 salt, address _poolOwner) external returns (address pool);

}