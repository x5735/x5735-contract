// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./contracts/token/ERC721/ERC721.sol";
import "./contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./contracts/access/Ownable.sol";

/**
 * MDAO Voucher NFT
 * @author MDAO
 */
contract MdaoVoucherNFT is ERC721Enumerable, Ownable {
    // base uri for nfts
    string private _buri;

    uint256 public lastIndex;

    constructor(string memory name, string memory symbol, string memory buri) ERC721(name, symbol) {
        require(bytes(buri).length > 0, "wrong base uri");
        _buri = buri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _buri;
    }

    function mint(address to) public onlyOwner returns(uint256) {
        uint256 currentIndex = lastIndex;
        lastIndex++;
        _safeMint(to, currentIndex);
        return currentIndex;
    }

    function burn(uint256 tokenId) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "burn caller is not owner nor approved"
        );
        _burn(tokenId);
    }
}