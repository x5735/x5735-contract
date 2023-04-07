// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LlamaLand.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract LlamaLandMetadata is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPDATE_ROLE = keccak256("UPDATE_ROLE");

    event UpdateSuccess(uint256 indexed tokenId);

    struct Metadata {
        string cid;
        string[9] info;
        uint32[7] body;
        uint32[6] ability;
        uint8 breed;
        uint8 rank;
    }

    mapping(uint => Metadata) public metadataMap;

    LlamaLand llamaLand;
    constructor(address _llamaLand) {
        llamaLand = LlamaLand(_llamaLand);
        _grantRole(ADMIN_ROLE, llamaLand.admin());
        _setRoleAdmin(UPDATE_ROLE, ADMIN_ROLE);
    }

    function updateMetadata(
        uint256 _tokenId,
        string memory _cid,
        string[9] memory _info,
        uint32[7] memory _body,
        uint32[6] memory _ability,
        uint8 _breed,
        uint8 _rank) external onlyRole(UPDATE_ROLE) {

        Metadata storage metadata = metadataMap[_tokenId];
        metadata.cid = _cid;
        metadata.info = _info;
        metadata.body = _body;
        metadata.ability = _ability;
        metadata.breed = _breed;
        metadata.rank = _rank;

        emit UpdateSuccess(_tokenId);
    }

    function updateRank(
        uint256 _tokenId,
        string memory _cid,
        uint32[6] memory _ability,
        uint8 _rank) external onlyRole(UPDATE_ROLE) {

        Metadata storage metadata = metadataMap[_tokenId];
        metadata.cid = _cid;
        metadata.ability = _ability;
        metadata.rank = _rank;

        emit UpdateSuccess(_tokenId);
    }

    function updateBreed(
        uint256 _tokenId,
        uint8 _breed) external onlyRole(UPDATE_ROLE) {

        Metadata storage metadata = metadataMap[_tokenId];
        metadata.breed = _breed;

        emit UpdateSuccess(_tokenId);
    }

    function getMetadata(uint256 _tokenId) external view returns (
        string memory,
        string[9] memory,
        uint32[7] memory,
        uint32[6] memory,
        uint8,
        uint8){
        Metadata memory metadata = metadataMap[_tokenId];
        return (metadata.cid, metadata.info, metadata.body, metadata.ability, metadata.breed, metadata.rank);
    }
}