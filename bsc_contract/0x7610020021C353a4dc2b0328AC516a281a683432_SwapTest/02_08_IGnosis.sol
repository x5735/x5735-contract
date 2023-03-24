// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IGnosos {
    function isOwner(address owner) external view returns (bool);
}