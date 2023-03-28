// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMaiWhitelist {
    function getUserWhitelistStatus(address) external view returns (bool);
}