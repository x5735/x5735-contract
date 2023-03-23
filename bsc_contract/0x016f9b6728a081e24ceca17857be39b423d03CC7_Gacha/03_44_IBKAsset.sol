// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBKAsset {
    function typeIdTrackers(uint256 typeId_) external view returns (uint256);

    function metadataOf(
        uint256 tokenId_
    ) external view returns (uint256 typeId, uint256 index);
}