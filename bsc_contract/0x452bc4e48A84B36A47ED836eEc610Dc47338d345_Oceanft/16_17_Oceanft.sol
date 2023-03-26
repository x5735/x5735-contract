// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./utils/TrustCaller.sol";

contract Oceanft is ERC721Enumerable, TrustCaller {
    event CollectionCreated(string collection);
    event CollectionRankURICreated(string collection, string rank, string uri);
    event MintTargetUpdated(address target);

    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private tokenCounter;
    string private _baseURIExtended = "ipfs://";

    string[] private collections;
    mapping(string => bool) private collectionMap;
    mapping(string => string[]) private collectionRanks;
    mapping(string => mapping(string => string)) public collectionRankURIMap;
    mapping(string => mapping(string => uint256)) public collectionRankTotal;

    address public mintTarget;
    mapping(uint256 => string) public tokenIdToRank;
    mapping(uint256 => string) public tokenIdToCollection;

    constructor() ERC721("Oceanft", "OCEAN") {}

    function allCollections() external view returns (string[] memory) {
        return collections;
    }

    function allRanksInCollection(string memory name_)
        external
        view
        returns (string[] memory)
    {
        return collectionRanks[name_];
    }

    function tokenInfo(uint256 tokenId)
        external
        view
        returns (
            string memory collection,
            string memory rank,
            string memory uri
        )
    {
        require(_exists(tokenId), "token does not exist");
        return (
            tokenIdToCollection[tokenId],
            tokenIdToRank[tokenId],
            collectionRankURIMap[tokenIdToCollection[tokenId]][
                tokenIdToRank[tokenId]
            ]
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory uri)
    {
        return
            collectionRankURIMap[tokenIdToCollection[tokenId]][
                tokenIdToRank[tokenId]
            ];
    }

    function burn(uint256 tokenId) external {
        require(_exists(tokenId), "token does not exist");
        require(
            ERC721.ownerOf(tokenId) == _msgSender(),
            "burn token that is not owner"
        );
        _burn(tokenId);
        delete tokenIdToCollection[tokenId];
        delete tokenIdToRank[tokenId];
    }

    // ================== Owner caller method ===============
    function setMintTarget(address mintTarget_) external onlyOwner {
        require(mintTarget_ != address(0), "unsupport zero address");
        mintTarget = mintTarget_;
        emit MintTargetUpdated(mintTarget_);
    }

    // ================== Trust caller method ===============

    function createCollection(string memory name_) external onlyTrustCaller {
        require(!collectionMap[name_], "collection is duplicated");
        collections.push(name_);
        string[] memory empty;
        collectionRanks[name_] = empty;
        collectionMap[name_] = true;
        emit CollectionCreated(name_);
    }

    function createCollectionRankWithURI(
        string memory name_,
        string memory rank_,
        string memory uri_
    ) external onlyTrustCaller {
        require(collectionMap[name_], "collection does not exist");
        require(
            bytes(collectionRankURIMap[name_][rank_]).length == 0,
            "rank is duplicated"
        );

        collectionRanks[name_].push(rank_);
        collectionRankURIMap[name_][rank_] = uri_;
        collectionRankTotal[name_][rank_] = 0;
        emit CollectionRankURICreated(name_, rank_, uri_);
    }

    function mint(string memory name_, string memory rank_)
        internal
    {
        tokenCounter.increment();
        uint256 tokenId = tokenCounter.current();
        _safeMint(mintTarget, tokenId);

        tokenIdToCollection[tokenId] = name_;
        tokenIdToRank[tokenId] = rank_;
        collectionRankTotal[name_][rank_] += 1;
    }


    function mintSize(string memory name_, string memory rank_, uint256 size)
        external
        onlyTrustCaller
    {
        require(
            bytes(collectionRankURIMap[name_][rank_]).length != 0,
            "collection and rank is not found"
        );
        require(mintTarget != address(0), "mint target not setup yet");
        for (uint256 i = 0; i <size; i++) { 
            mint(name_, rank_);
        }
    }
}