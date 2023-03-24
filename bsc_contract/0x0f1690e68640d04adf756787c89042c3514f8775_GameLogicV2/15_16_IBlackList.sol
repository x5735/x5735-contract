// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IBlackList {
    function addToBlackList(address _user) external;

    function removeFromBlackList(address _user) external;

    function inBlackList(address _user) external view returns (bool);

    function notInBlackList(address _user) external view returns (bool);
}