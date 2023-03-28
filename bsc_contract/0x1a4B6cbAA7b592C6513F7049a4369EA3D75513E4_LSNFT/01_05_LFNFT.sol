// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";

contract LSNFT is ERC721A, Ownable {

    string private baseURI = "ipfs://QmVaU6NHKtwSjCaW7W5TMsawnqPG2jhGSuiQwzojF7tasB/";
    string private baseExtension = ".json";

    constructor() ERC721A("LSNFT", "LSNFT") {}

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert("token not exist");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, _toString(tokenId), baseExtension))
            : "";
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function batchMint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0));
        require(quantity > 0, "wrong quantity");
        _safeMint(to, quantity);
    }
}