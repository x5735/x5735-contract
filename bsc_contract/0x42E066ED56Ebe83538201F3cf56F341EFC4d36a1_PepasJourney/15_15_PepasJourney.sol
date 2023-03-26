// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract PepasJourney is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;


    // Map the number of tokens per pepaId
    mapping(uint8 => uint256) public pepaCount;

    // Map the number of tokens burnt per pepaId
    mapping(uint8 => uint256) public pepaBurnCount;

    // Used for generating the tokenId of new NFT minted
    Counters.Counter private _tokenIds;

    // Map the pepaId for each tokenId
    mapping(uint256 => uint8) private pepaIds;

    // Map the pepaEdition for each tokenId
    mapping(uint256 => uint256) private pepaEditions;

    // Map the pepaName for a tokenId
    mapping(uint8 => string) private pepaNames;

    // Map the baseURI for each pepaId
    mapping(uint8 => string) private baseURIs;

    // minter authorization
    mapping(address => bool) private isMinter;


    modifier onlyMinter() {
        require(isMinter[msg.sender], "Only minter");
        _;
    }

    constructor() ERC721("Pepa's Journey", "PEPANFT") {
    }

    /**
     * @dev Get pepaId for a specific tokenId.
     */
    function getPepaId(uint256 _tokenId) external view returns (uint8) {
        return pepaIds[_tokenId];
    }

    /**
     * @dev Get pepaEdition for a specific tokenId.
     */
    function getPepaEdition(uint256 _tokenId) external view returns (uint256) {
        return pepaEditions[_tokenId];
    }

    /**
     * @dev Get the associated pepaName for a specific pepaId.
     */
    function getPepaName(uint8 _pepaId)
        external
        view
        returns (string memory)
    {
        return pepaNames[_pepaId];
    }

    /**
     * @dev Get the associated bunnyName for a unique tokenId.
     */
    function getPepaNameOfTokenId(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        uint8 pepaId = pepaIds[_tokenId];
        return pepaNames[pepaId];
    }

    /**
     * @dev Mint NFTs. Only the owner can call it.
     */
    function mint(
        address _to,
        uint8 _pepaId
    ) external onlyMinter returns (uint256) {
        _tokenIds.increment();
        uint256 newId = _tokenIds.current();
        pepaIds[newId] = _pepaId;

        pepaCount[_pepaId] += 1;
        pepaEditions[newId] = pepaCount[_pepaId];

        _safeMint(_to, newId);

        return newId;
    }

    /**
     * @dev Set a unique name and baseURI for each pepaId. It is supposed to be called once.
     */
    function setPepa(uint8 _pepaId, string calldata _name, string calldata _baseURI)
        external
        onlyOwner
    {
        pepaNames[_pepaId] = _name;
        baseURIs[_pepaId] = _baseURI;
    }

    /**
     * @dev Burn a NFT token. Callable by minter only.
     */
    function burn(uint256 _tokenId) external onlyMinter {
        uint8 pepaIdBurnt = pepaIds[_tokenId];
        pepaCount[pepaIdBurnt] = pepaCount[pepaIdBurnt] - 1;
        pepaBurnCount[pepaIdBurnt] = pepaBurnCount[pepaIdBurnt] + 1;
        _burn(_tokenId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        uint8 pepaId = pepaIds[tokenId];
        uint256 pepaEdition = pepaEditions[tokenId];

        string memory baseURI = baseURIs[pepaId];
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, pepaEdition.toString())) : "";
    }

    /**
     * @dev Configure minting permissions for address.
     */
    function setMinter(address _minter, bool _isMinter) external onlyOwner {
        isMinter[_minter] = _isMinter;
    }
}