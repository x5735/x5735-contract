// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IToken {
    function rewards(address account, uint256 amount) external;

    function transfer(address to, uint256 amount) external returns (bool);
}