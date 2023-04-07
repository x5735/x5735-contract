// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function getRatesDetail(bytes32 key) external view returns (uint216 baseRate, uint216 rate, address token, bool valid);
}