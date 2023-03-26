// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import {Address as Address2} from './Address.sol';

contract ZKBridgeCreator721 is ERC721, Ownable {
    string private _baseUri;

    constructor(string memory name_, string memory symbol_, string memory uri_) ERC721(name_, symbol_) {
        _baseUri = uri_;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return
        string(
            abi.encodePacked(
                _baseUri,
                '0x',
                Address2.toChecksumString(address(this)),
                '/',
                Strings.toString(tokenId),
                '.json'
            )
        );
    }

    function mint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        _safeMint(to, tokenId, data);
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function setBaseUri(string memory uri_) external onlyOwner {_baseUri = uri_;}

}