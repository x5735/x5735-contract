// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SpaceAnimalsNFT is ERC721, Ownable, ERC721Burnable, ERC721URIStorage {
    address public signatory;
    string public baseURI;

    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    event Pack(address accounts, uint256 tokenId);
    event Unpack(address accounts, uint256 tokenId);
    event SetTokenURI(uint256 tokenId, string _tokenURI);

    constructor(address _signatory) ERC721("Space Animals NFT", "SANFT") {
        signatory = _signatory;
    }

    function pack(uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s, string memory _tokenURI) external {
        require(permit(msg.sender, tokenId, deadline, v, r, s), "execution denied");

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        emit Pack(msg.sender, tokenId);
        emit SetTokenURI(tokenId, _tokenURI);
    }

    function unpack(uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(permit(msg.sender, tokenId, deadline, v, r, s), "execution denied");

        burn(tokenId);
        emit Unpack(msg.sender, tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not owner nor approved");

        _setTokenURI(tokenId, _tokenURI);
        emit SetTokenURI(tokenId, _tokenURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function setBaseURI(string memory newURI) external onlyOwner {
        baseURI = newURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function appendStrings(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function permit(address account, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 domainSeparator = keccak256(abi.encode(keccak256("EIP712Domain(string name)"), keccak256(bytes("Space Animals NFT"))));

        bytes32 structHash = keccak256(abi.encode(keccak256("Permit(uint256 account,uint256 tokenId,uint256 deadline)"), account, tokenId, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        address _signatory = ecrecover(digest, v, r, s);

        if (_signatory == address(0) || signatory != _signatory || block.timestamp > deadline) {
            return false;
        }

        return true;
    }

    function arrayOfTokens(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokens = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = _ownedTokens[owner][i];
        }

        return tokens;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from != to) {
            if (from != address(0)) {
                _removeTokenFromOwnerEnumeration(from, tokenId);
            }
            if (to != address(0)) {
                _addTokenToOwnerEnumeration(to, tokenId);
            }
        }
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}