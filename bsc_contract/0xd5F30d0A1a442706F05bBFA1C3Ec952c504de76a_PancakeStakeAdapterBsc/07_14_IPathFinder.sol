// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

interface IPathFinder {
    function getPaths(
        address _router,
        address _inToken,
        address _outToken
    ) external view returns (address[] memory);
}