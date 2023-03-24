// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IRole {
    function isCEO(address addr) external view returns (bool);

    function isCOO(address addr) external view returns (bool);

    function isCFO(address addr) external view returns (bool);

    function isCXO(address addr) external view returns (bool);

    function isCTO(address addr) external view returns (bool);
}