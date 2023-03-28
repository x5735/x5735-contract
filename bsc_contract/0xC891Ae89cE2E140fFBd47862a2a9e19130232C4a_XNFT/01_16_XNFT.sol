// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract XNFT is ERC721URIStorage, ERC721Enumerable, ERC2981, Ownable {
    constructor(address owner, address minter, uint96 royaltyRate) ERC721("PROJECT XENO", "XENO-NFT") {
        require(minter != address(0), "XNFT: minter cant't be zero address");
        require(owner != address(0), "XNFT: owner can't be zero address");
        _minter = minter;
        _transferOwnership(owner);
        _setDefaultRoyalty(owner, royaltyRate);
    }
    address private _minter;

    modifier onlyAuth() {
        require(_msgSender() == getMinter() || _msgSender() == owner(), "caller is not authorized.");
        _;
    }

    function mint(string memory uri, uint256 tokenId) public onlyAuth {
        _safeMint(owner(), tokenId);
        _setTokenURI(tokenId, uri);
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyAuth {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

   function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId) 
            || ERC2981.supportsInterface(interfaceId)
            ||super.supportsInterface(interfaceId);
    }

    function isMined(uint256 tokenId) public view returns(bool) {
        return _exists(tokenId);
    }

    function getMinter() public view returns(address) {
        return _minter;
    }

    function changeMinter(address newMinter) external onlyAuth {
        require(newMinter != address(0), "Invalid address: address(0x0)");
        _minter = newMinter;
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyAuth {
        super._setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() public onlyAuth {
        super._deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public onlyAuth {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) public onlyAuth {
        super._resetTokenRoyalty(tokenId);
    }
}