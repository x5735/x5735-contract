// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDataFeed {
    function latestAnswer() external view returns (int256 answer);

    function decimals() external view returns (uint8);
}