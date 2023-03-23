// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IMunInfo {
    
    struct AttachedMiner {
        uint256 parcelId;
        uint256 minerId;
    }
    
    function getBundles(address _user) external view returns (uint256[6][17] memory bundleStats);
    function getUserMiners(address _user) external view returns (AttachedMiner[] memory);
}