//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Mr is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    // keep track of tokenIds
    Counters.Counter private _tokenIds;

    // address of marketplace for NFTs to interact
    address public marketplaceAddress;

    constructor(address _marketplaceAddress) ERC721("Heritage", "HERI") {
        marketplaceAddress = _marketplaceAddress;
        _tokenIds.increment(); // tokenId start form 1

        for (uint256 i = 0; i < 6; i++) mintToken();
    }

    function mintToken() public onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);

        // set the token URI: id and uri
        _setTokenURI(
            newItemId,
            string(
                abi.encodePacked(
                    "https://storage.googleapis.com/l1bank/heritage/json/",
                    newItemId.toString(),
                    ".json"
                )
            )
        );
        // give the marketplace the approval to transact between users
        // setApprovalForAll allows marketplace to do that with contract address
        setApprovalForAll(marketplaceAddress, true);
        // increase tokenId for next NFT
        _tokenIds.increment();

        // mint the token - return the id
        return newItemId;
    }

    // @notice function to mint the token by batch
    // @params _nftContract
    function mintTokenByBatch(
        uint256 _startTokenId,
        uint256 _endTokenId
    ) public onlyOwner {
          for (uint256 i = _startTokenId; i < _endTokenId; i++) mintToken();
    }

}