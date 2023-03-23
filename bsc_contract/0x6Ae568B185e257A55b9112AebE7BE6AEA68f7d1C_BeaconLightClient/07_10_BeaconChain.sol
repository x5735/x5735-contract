// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./MerkleProof.sol";
import "./ScaleCodec.sol";

contract BeaconChain is MerkleProof {
    uint64 constant internal SYNC_COMMITTEE_SIZE = 512;

    struct ForkData {
        bytes4 currentVersion;
        bytes32 genesisValidatorsRoot;
    }

    struct SigningData {
        bytes32 objectRoot;
        bytes32 domain;
    }

    struct BeaconBlockHeader {
        uint64 slot;
        uint64 proposerIndex;
        bytes32 parentRoot;
        bytes32 stateRoot;
        bytes32 bodyRoot;
    }

    // Return the signing root for the corresponding signing data.
    function computeSigningRoot(BeaconBlockHeader memory beaconHeader, bytes32 domain) internal pure returns (bytes32){
        return hashTreeRoot(SigningData({
                objectRoot: hashTreeRoot(beaconHeader),
                domain: domain
            })
        );
    }

    // Return the 32-byte fork data root for the ``current_version`` and ``genesis_validators_root``.
    // This is used primarily in signature domains to avoid collisions across forks/chains.
    function computeForkDataRoot(bytes4 currentVersion, bytes32 genesisValidatorsRoot) internal pure returns (bytes32){
        return hashTreeRoot(ForkData({
                currentVersion: currentVersion,
                genesisValidatorsRoot: genesisValidatorsRoot
            })
        );
    }

    //  Return the domain for the ``domain_type`` and ``fork_version``.
    function computeDomain(bytes4 domainType, bytes4 forkVersion, bytes32 genesisValidatorsRoot) internal pure returns (bytes32){
        bytes32 forkDataRoot = computeForkDataRoot(forkVersion, genesisValidatorsRoot);
        return bytes32(domainType) | forkDataRoot >> 32;
    }

    function hashTreeRoot(ForkData memory fork_data) internal pure returns (bytes32) {
        return hashNode(bytes32(fork_data.currentVersion), fork_data.genesisValidatorsRoot);
    }

    function hashTreeRoot(SigningData memory signingData) internal pure returns (bytes32) {
        return hashNode(signingData.objectRoot, signingData.domain);
    }

    function hashTreeRoot(BeaconBlockHeader memory beaconHeader) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](5);
        leaves[0] = bytes32(toLittleEndian64(beaconHeader.slot));
        leaves[1] = bytes32(toLittleEndian64(beaconHeader.proposerIndex));
        leaves[2] = beaconHeader.parentRoot;
        leaves[3] = beaconHeader.stateRoot;
        leaves[4] = beaconHeader.bodyRoot;
        return merkleRoot(leaves);
    }

    function toLittleEndian64(uint64 value) internal pure returns (bytes8) {
        return ScaleCodec.encode64(value);
    }

    function toLittleEndian256(uint256 value) internal pure returns (bytes32) {
        return ScaleCodec.encode256(value);
    }
}