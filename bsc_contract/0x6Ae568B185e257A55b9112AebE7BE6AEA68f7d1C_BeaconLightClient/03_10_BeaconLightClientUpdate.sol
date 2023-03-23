// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./BeaconChain.sol";

contract BeaconLightClientUpdate is BeaconChain {

    struct SyncAggregate {
        uint64 participation;
        Groth16Proof proof;
    }

    struct Groth16Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[3] input;
    }

    struct FinalizedHeaderUpdate {
        // The beacon block header that is attested to by the sync committee
        BeaconBlockHeader attestedHeader;

        // Sync committee corresponding to sign attested header
        bytes32 syncCommitteeRoot;

        // The finalized beacon block header attested to by Merkle branch
        BeaconBlockHeader finalizedHeader;
        bytes32[] finalityBranch;

        // Fork version for the aggregate signature
        bytes4 forkVersion;

        // Slot at which the aggregate signature was created (untrusted)
        uint64 signatureSlot;

        // Sync committee aggregate signature
        SyncAggregate syncAggregate;
    }

    struct SyncCommitteePeriodUpdate {
        // Next sync committee corresponding to the finalized header
        bytes32 nextSyncCommitteeRoot;
        bytes32[] nextSyncCommitteeBranch;
    }
}