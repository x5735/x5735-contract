// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LlamaLandRelic.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract LlamaLandRelicMetadata is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPDATE_ROLE = keccak256("UPDATE_ROLE");

    struct Metadata {
        string cid;
        uint32[6] abilities;
    }

    mapping(uint => Metadata) metadataMap;

    event Update(uint indexed tokenId, string cid, uint32[6] abilities);

    LlamaLandRelic relic;

    constructor(address _relic) {
        relic = LlamaLandRelic(_relic);

        _grantRole(ADMIN_ROLE, relic.admin());
        _setRoleAdmin(UPDATE_ROLE, ADMIN_ROLE);
    }

    function update(uint _tokenId, string memory _cid, uint32[6] memory _abilities)
    onlyRole(UPDATE_ROLE)
    external {
        Metadata storage metadata = metadataMap[_tokenId];
        metadata.cid = _cid;
        metadata.abilities = _abilities;
        emit Update(_tokenId, _cid, _abilities);
    }

    function getMetadata(uint tokenId)
    view
    external
    returns (
        Metadata memory
    ) {
        return metadataMap[tokenId];
    }
}