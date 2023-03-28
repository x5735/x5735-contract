// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";

contract GENESISPASS is ERC721A("GENESISPASS", "GENESISPASS"), Ownable {
    string public baseURI = "ipfs://QmUMJyjiKFZYRicyHCoJMCgLdZGYpLeQik4veSA4VJVPM7";
    uint256 public maxSupply = 3100;

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert("token not exist");
        return baseURI;
    }

    function batchMint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0));
        require(quantity >= 1 && totalSupply() + quantity <= maxSupply, "max supply limit");
        _safeMint(to, quantity);
    }
}