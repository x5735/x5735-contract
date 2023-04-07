// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./lib/base64.sol";
import "./IMetobadgeFactory.sol";
import "./ISpaceRegistration.sol";

error Soulbound();

contract MetopianBadge is ERC721, Ownable {
    event Mint(
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        uint256 indexed spaceId
    );
    event Update(uint256 indexed tokenId);

    using Counters for Counters.Counter;

    IMetobadgeFactory sbtFactory;
    ISpaceRegistration spaceRegistration;

    constructor(
        address sbtFactoryAddr,
        address spaceRegistrationAddr
    ) ERC721("Metobadge", "MTB") {
        sbtFactory = IMetobadgeFactory(sbtFactoryAddr);
        spaceRegistration = ISpaceRegistration(spaceRegistrationAddr);
    }

    struct Token {
        uint256 id;
        uint256 collectionId;
        mapping(string => uint256) fieldIndices;
        string[] fields;
        string[] values;
        uint256 createtime;
        uint level;
    }

    Counters.Counter _tokenId;
    Token[] public tokens;

    mapping(uint256 => Counters.Counter) _tokenIdCounters;
    mapping(uint256 => mapping(address => uint256)) private _holdings;

    string private imageRenderURI = "https://ai.metopia.xyz/metobadge";

    function mint(
        address to,
        uint256 collectionId,
        string[] memory fields,
        string[] memory values,
        bytes calldata _sig
    ) public {
        require(_holdings[collectionId][to] == 0, "duplicate");

        bytes32 messageHash = getMintMessageHash(
            to,
            collectionId,
            fields,
            values
        );
        require(
            spaceRegistration.verifySignature(
                sbtFactory.collection(collectionId).spaceId,
                messageHash,
                _sig
            ),
            "auth failed"
        );

        doMint(to, collectionId, fields, values);
        emit Mint(
            _tokenId.current(),
            collectionId,
            sbtFactory.collection(collectionId).spaceId
        );
    }

    function update(
        uint256 id,
        string[] memory fields,
        string[] memory values,
        uint level,
        bytes calldata _sig
    ) public {
        require(id <= _tokenId.current(), "Invalid id");
        Token storage token = tokens[id - 1];
        bytes32 messageHash = getUpdateMessageHash(id, fields, values, level);
        require(
            spaceRegistration.verifySignature(
                sbtFactory.collection(token.collectionId).spaceId,
                messageHash,
                _sig
            ),
            "auth failed"
        );

        updateTokenAttrs(token, fields, values);
        token.level = level;
        emit Update(id);
    }

    function mintWithProof(
        address to,
        uint256 collectionId,
        string[] memory fields,
        string[] memory values,
        bytes32 root,
        bytes32[] calldata _merkleProof
    ) public {
        require(_holdings[collectionId][to] == 0, "duplicate");

        bytes32 messageHash = getMintMessageHash(
            to,
            collectionId,
            fields,
            values
        );
        require(
            spaceRegistration.checkMerkle(
                sbtFactory.collection(collectionId).spaceId,
                root,
                messageHash,
                _merkleProof
            ),
            "auth failed"
        );
        doMint(to, collectionId, fields, values);
        emit Mint(
            _tokenId.current(),
            collectionId,
            sbtFactory.collection(collectionId).spaceId
        );
    }

    function updateWithProof(
        uint256 id,
        string[] memory fields,
        string[] memory values,
        uint level,
        bytes32 root,
        bytes32[] calldata _merkleProof
    ) public {
        require(id <= _tokenId.current(), "Invalid id");
        Token storage token = tokens[id - 1];
        bytes32 messageHash = getUpdateMessageHash(id, fields, values, level);
        require(
            spaceRegistration.checkMerkle(
                sbtFactory.collection(token.collectionId).spaceId,
                root,
                messageHash,
                _merkleProof
            ),
            "auth failed"
        );

        updateTokenAttrs(token, fields, values);
        token.level = level;
        emit Update(id);
    }

    function doMint(
        address to,
        uint256 collectionId,
        string[] memory fields,
        string[] memory values
    ) private {
        _tokenIdCounters[collectionId].increment();
        _tokenId.increment();
        _safeMint(to, _tokenId.current());
        _holdings[collectionId][to] = _tokenId.current();

        Token storage token = tokens.push();
        token.id = _tokenIdCounters[collectionId].current();
        token.collectionId = collectionId;
        token.createtime = block.timestamp;

        updateTokenAttrs(token, fields, values);
    }

    function updateTokenAttrs(
        Token storage token,
        string[] memory fields,
        string[] memory values
    ) private {
        for (uint256 i = 0; i < fields.length; i++) {
            if (token.fieldIndices[fields[i]] > 0) {
                token.values[token.fieldIndices[fields[i]] - 1] = values[i];
            } else {
                token.fields.push(fields[i]);
                token.values.push(values[i]);
                token.fieldIndices[fields[i]] = token.fields.length;
            }
        }
    }

    function attrs2JsonStr(
        string[] memory fields,
        string[] memory values
    ) private pure returns (bytes memory) {
        bytes memory buff;
        for (uint256 i = 0; i < fields.length; i++) {
            buff = bytes(
                abi.encodePacked(
                    buff,
                    ',{"trait_type":"',
                    fields[i],
                    '","value":"',
                    values[i],
                    '"}'
                )
            );
        }
        return buff;
    }

    function tokenAttrs2JsonStr(
        uint256 id
    ) private view returns (bytes memory) {
        bytes memory buff;
        Token storage token = tokens[id - 1];
        buff = bytes(
            abi.encodePacked(buff, attrs2JsonStr(token.fields, token.values))
        );

        return buff;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenId.current();
    }

    function supply(uint256 collectionId) public view returns (uint256) {
        return _tokenIdCounters[collectionId].current();
    }

    function attr(
        uint tokenId,
        string memory field
    ) public view returns (string memory) {
        Token storage token = tokens[tokenId - 1];

        for (uint256 i = 0; i < token.fields.length; i++) {
            if (keccak256(bytes(token.fields[i])) == keccak256(bytes(field))) {
                return token.values[i];
            }
        }
        return "";
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        require(id <= _tokenId.current(), "invalid id");
        return constructTokenURI(id);
    }

    function tokenImageUrl(uint256 id) public view returns (string memory) {
        return
            string(
                abi.encodePacked(imageRenderURI, "?id=", Strings.toString(id))
            );
    }

    function holdingByOwner(
        address addr,
        uint256 collectionId
    ) public view returns (uint256) {
        return _holdings[collectionId][addr];
    }

    function constructTokenURI(
        uint256 id
    ) private view returns (string memory) {
        Token storage token = tokens[id - 1];
        IMetobadgeFactory.Collection memory collection = sbtFactory.collection(
            token.collectionId
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                "{",
                                '"name":"',
                                collection.name,
                                '",',
                                '"description":"',
                                collection.description,
                                '",',
                                '"image":"',
                                tokenImageUrl(id),
                                '",',
                                '"collectionId":"',
                                Strings.toString(token.collectionId),
                                '",',
                                '"level":"',
                                Strings.toString(token.level),
                                '",',
                                '"attributes":[',
                                '{"trait_type":"Space", "value":"',
                                collection.signerName,
                                '"}',
                                tokenAttrs2JsonStr(id),
                                "]}"
                            )
                        )
                    )
                )
            );
    }

    function setSBTFactory(address addr) public onlyOwner {
        sbtFactory = IMetobadgeFactory(addr);
    }

    function setSpaceRegistration(address addr) public onlyOwner {
        spaceRegistration = ISpaceRegistration(addr);
    }

    function setImageRenderURI(string memory uri) public onlyOwner {
        imageRenderURI = uri;
    }

    function getMintMessageHash(
        address addr,
        uint256 collectionId,
        string[] memory fields,
        string[] memory values
    ) public pure returns (bytes32) {
        bytes memory buff = abi.encodePacked(addr, collectionId);
        for (uint256 i = 0; i < fields.length; i++) {
            buff = abi.encodePacked(buff, fields[i], values[i]);
        }
        return keccak256(buff);
    }

    function getUpdateMessageHash(
        uint256 id,
        string[] memory fields,
        string[] memory values,
        uint level
    ) public pure returns (bytes32) {
        bytes memory buff = abi.encodePacked(id);
        for (uint256 i = 0; i < fields.length; i++) {
            buff = abi.encodePacked(buff, fields[i], values[i]);
        }
        buff = abi.encodePacked(buff, level);
        return keccak256(buff);
    }

    function burn(uint256 tokenId) public {
        Token storage token = tokens[tokenId - 1];
        IMetobadgeFactory.Collection memory collection = sbtFactory.collection(
            token.collectionId
        );
        require(
            (collection.lifespan > 0 &&
                collection.lifespan + token.createtime > block.timestamp) ||
                _isApprovedOrOwner(msg.sender, tokenId) ||
                spaceRegistration.isAdmin(collection.spaceId, msg.sender),
            "not burnable"
        );
        _holdings[token.collectionId][ownerOf(tokenId)] = 0;
        _burn(tokenId);
    }

    /**
     * @notice SOULBOUND: Block transfers.
     */
    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal virtual override {
    //     require(from == address(0) || to == address(0), "nontransferable");
    //     super._beforeTokenTransfer(from, to, tokenId);
    // }

    /**
     * @notice SOULBOUND: Block approvals.
     */
    function setApprovalForAll(
        address operator,
        bool _approved
    ) public virtual override {
        revert Soulbound();
    }

    /**
     * @notice SOULBOUND: Block approvals.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        revert Soulbound();
    }
}