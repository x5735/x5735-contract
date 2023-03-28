// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ICoriteMNFT {
    function mint(address _to, uint _tokenId) external;

    function burn(uint _tokenId) external;

    function ownerOf(uint _tokenId) external returns (address);
}