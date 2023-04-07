// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DebtEcosystem is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    struct Meta {
        string project;
        string key;
    }

    Counters.Counter private _tokenIdCounter;
    string private _name = "D.E.B.T. Ecosystem";
    string private _symbol = "DEBT";
    string private baseURI;
    string public contractURI;
    mapping(uint256 => Meta) private _tokenToMeta;
    mapping(string => uint256) private _keyToToken;

    constructor(
        string memory baseURI_,
        string memory contractURI_
    ) ERC721(_name, _symbol) {
        setBaseURI(baseURI_);
        setContractURI(contractURI_);
        // start at tokenId 1
        _tokenIdCounter.increment();
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        baseURI = baseURI_;
    }

    function setContractURI(string memory contractURI_) public onlyOwner {
        contractURI = contractURI_;
    }

    function safeMint(
        address to,
        string calldata key,
        string calldata project
    ) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // key
        require(!_keyExists(key), "DebtEcosystem: key already minted");
        _keyToToken[key] = tokenId;
        // meta
        Meta memory meta = Meta(project, key);
        _tokenToMeta[tokenId] = meta;

        _safeMint(to, tokenId);
    }

    function safeMintBatch(
        address to,
        string[] calldata keys,
        string calldata project
    ) public onlyOwner {
        for (uint256 i = 0; i < keys.length; i++) {
            safeMint(to, keys[i], project);
        }
    }

    function tokensOfOwner(
        address owner
    ) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenList = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenList[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenList;
    }

    function metaOf(uint256 tokenId) public view returns (Meta memory) {
        require(_exists(tokenId), "DebtEcosystem: invalid token ID");
        return _tokenToMeta[tokenId];
    }

    function keyOf(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "DebtEcosystem: invalid token ID");
        return _tokenToMeta[tokenId].key;
    }

    function projectOf(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "DebtEcosystem: invalid token ID");
        return _tokenToMeta[tokenId].project;
    }

    function tokenByKey(string memory key) public view returns (uint256) {
        require(_keyExists(key), "DebtEcosystem: invalid key");
        return _keyToToken[key];
    }

    function nextTokenId() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function _keyExists(string memory key) private view returns (bool) {
        return _keyToToken[key] != 0;
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        Meta memory meta = _tokenToMeta[tokenId];
        delete _keyToToken[meta.key];
        delete _tokenToMeta[tokenId];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}