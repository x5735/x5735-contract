// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AkiLimitedGenericERC721NFT.sol";

contract AkiLimitedContract is AkiLimitedGenericERC721NFT {
    constructor(string memory _name, string memory _symbol, string memory _tokenURI, uint256 _totalSupply) AkiLimitedGenericERC721NFT(
        _name, 
        _symbol,
        _tokenURI,
        _totalSupply
    ) {}
}