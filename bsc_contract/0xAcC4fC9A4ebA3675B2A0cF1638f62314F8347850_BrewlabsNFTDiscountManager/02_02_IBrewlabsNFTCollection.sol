pragma solidity >=0.5.0;

interface IBrewlabsNFTCollection {
    // nft collection contract must implement these 2 methods in its code
    function getAttributeRarity(uint tokenId) external view returns(uint8);
    function tokensOfOwner(address owner) external view returns(uint[] memory);
}