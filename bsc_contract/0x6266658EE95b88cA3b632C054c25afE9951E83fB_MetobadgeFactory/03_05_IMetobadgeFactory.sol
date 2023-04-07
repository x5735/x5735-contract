// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IMetobadgeFactory {
    struct Collection {
        uint256 spaceId;
        string name;
        string description;
        string signerName;
        string signerLogo;
        uint256 lifespan;
    }

    function collection(uint256 id) external view returns (Collection memory);
}