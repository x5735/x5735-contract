// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./BeaconLightClientUpdate.sol";
import "./LightClientVerifier.sol";
import "./BLS12381.sol";

contract BeaconLightClient is LightClientVerifier, BeaconLightClientUpdate, BLS12381,Initializable {
    // Beacon block header that is finalized
    BeaconBlockHeader public finalizedHeader;

    // slot=>BeaconBlockHeader
    mapping(uint64 => BeaconBlockHeader) public headers;

    // Sync committees corresponding to the header
    // sync_committee_perid => sync_committee_root
    mapping(uint64 => bytes32) public syncCommitteeRoots;

    bytes32 public GENESIS_VALIDATORS_ROOT;

    uint64 constant private NEXT_SYNC_COMMITTEE_INDEX = 55;
    uint64 constant private NEXT_SYNC_COMMITTEE_DEPTH = 5;
    uint64 constant private FINALIZED_CHECKPOINT_ROOT_INDEX = 105;
    uint64 constant private FINALIZED_CHECKPOINT_ROOT_DEPTH = 6;
    uint64 constant private SLOTS_PER_EPOCH = 32;
    uint64 constant private EPOCHS_PER_SYNC_COMMITTEE_PERIOD = 256;
    bytes4 constant private DOMAIN_SYNC_COMMITTEE = 0x07000000;

    event FinalizedHeaderImported(BeaconBlockHeader finalized_header);
    event NextSyncCommitteeImported(uint64 indexed period, bytes32 indexed next_sync_committee_root);

    function initialize(
        uint64 slot,
        uint64 proposerIndex,
        bytes32 parentRoot,
        bytes32 stateRoot,
        bytes32 bodyRoot,
        bytes32 currentSyncCommitteeHash,
        bytes32 nextSyncCommitteeHash,
        bytes32 genesisValidatorsRoot) public initializer {
        finalizedHeader = BeaconBlockHeader(slot, proposerIndex, parentRoot, stateRoot, bodyRoot);
        syncCommitteeRoots[computeSyncCommitteePeriod(slot)] = currentSyncCommitteeHash;
        syncCommitteeRoots[computeSyncCommitteePeriod(slot) + 1] = nextSyncCommitteeHash;
        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
    }

    function getCurrentPeriod() public view returns (uint64) {
        return computeSyncCommitteePeriod(finalizedHeader.slot);
    }

    function getCommitteeRoot(uint64 slot) public view returns (bytes32) {
        return syncCommitteeRoots[computeSyncCommitteePeriod(slot)];
    }

    // follow beacon api: /beacon/light_client/updates/?start_period={period}&count={count}
    function importNextSyncCommittee(
        FinalizedHeaderUpdate calldata headerUpdate,
        SyncCommitteePeriodUpdate calldata scUpdate
    ) external {
        require(isSuperMajority(headerUpdate.syncAggregate.participation), "!supermajor");

        require(headerUpdate.signatureSlot > headerUpdate.attestedHeader.slot &&
            headerUpdate.attestedHeader.slot >= headerUpdate.finalizedHeader.slot,
            "!skip");

        require(verifyFinalizedHeader(
                headerUpdate.finalizedHeader,
                headerUpdate.finalityBranch,
                headerUpdate.attestedHeader.stateRoot),
            "!finalized header"
        );

        uint64 finalizedPeriod = computeSyncCommitteePeriod(headerUpdate.finalizedHeader.slot);
        uint64 signaturePeriod = computeSyncCommitteePeriod(headerUpdate.signatureSlot);
        require(signaturePeriod == finalizedPeriod, "!period");

        bytes32 signatureSyncCommitteeRoot = syncCommitteeRoots[signaturePeriod];
        require(signatureSyncCommitteeRoot != bytes32(0), "!missing");
        require(signatureSyncCommitteeRoot == headerUpdate.syncCommitteeRoot, "!sync_committee");


        bytes32 domain = computeDomain(DOMAIN_SYNC_COMMITTEE, headerUpdate.forkVersion, GENESIS_VALIDATORS_ROOT);
        bytes32 signingRoot = computeSigningRoot(headerUpdate.attestedHeader, domain);

        uint256[28] memory fieldElement = hashToField(signingRoot);
        uint256[31] memory verifyInputs;
        for (uint256 i = 0; i < fieldElement.length; i++) {
            verifyInputs[i] = fieldElement[i];
        }
        verifyInputs[28] = headerUpdate.syncAggregate.proof.input[0];
        verifyInputs[29] = headerUpdate.syncAggregate.proof.input[1];
        verifyInputs[30] = headerUpdate.syncAggregate.proof.input[2];

        require(verifyProof(
                headerUpdate.syncAggregate.proof.a,
                headerUpdate.syncAggregate.proof.b,
                headerUpdate.syncAggregate.proof.c,
                verifyInputs), "invalid proof");

        bytes32 syncCommitteeRoot = bytes32((headerUpdate.syncAggregate.proof.input[1] << 128) | headerUpdate.syncAggregate.proof.input[0]);
        uint64 slot = uint64(headerUpdate.syncAggregate.proof.input[2]);
        require(syncCommitteeRoot == signatureSyncCommitteeRoot, "invalid syncCommitteeRoot");
//        require(slot == headerUpdate.signatureSlot, "invalid slot");

        if (headerUpdate.finalizedHeader.slot > finalizedHeader.slot) {
            finalizedHeader = headerUpdate.finalizedHeader;
            headers[finalizedHeader.slot] = finalizedHeader;
            emit FinalizedHeaderImported(headerUpdate.finalizedHeader);
        }

        require(verifyNextSyncCommittee(
                scUpdate.nextSyncCommitteeRoot,
                scUpdate.nextSyncCommitteeBranch,
                headerUpdate.attestedHeader.stateRoot),
            "!next_sync_committee"
        );

        uint64 nextPeriod = signaturePeriod + 1;
        require(syncCommitteeRoots[nextPeriod] == bytes32(0), "imported");
        bytes32 nextSyncCommitteeRoot = scUpdate.nextSyncCommitteeRoot;
        syncCommitteeRoots[nextPeriod] = nextSyncCommitteeRoot;
        emit NextSyncCommitteeImported(nextPeriod, nextSyncCommitteeRoot);
    }

    function verifyFinalizedHeader(
        BeaconBlockHeader calldata header,
        bytes32[] calldata finalityBranch,
        bytes32 attestedHeaderRoot
    ) internal pure returns (bool) {
        require(finalityBranch.length == FINALIZED_CHECKPOINT_ROOT_DEPTH, "!finality_branch");
        bytes32 headerRoot = hashTreeRoot(header);
        return isValidMerkleBranch(
            headerRoot,
            finalityBranch,
            FINALIZED_CHECKPOINT_ROOT_DEPTH,
            FINALIZED_CHECKPOINT_ROOT_INDEX,
            attestedHeaderRoot
        );
    }

    function verifyNextSyncCommittee(
        bytes32 nextSyncCommitteeRoot,
        bytes32[] calldata nextSyncCommitteeBranch,
        bytes32 headerStateRoot
    ) internal pure returns (bool) {
        require(nextSyncCommitteeBranch.length == NEXT_SYNC_COMMITTEE_DEPTH, "!next_sync_committee_branch");
        return isValidMerkleBranch(
            nextSyncCommitteeRoot,
            nextSyncCommitteeBranch,
            NEXT_SYNC_COMMITTEE_DEPTH,
            NEXT_SYNC_COMMITTEE_INDEX,
            headerStateRoot
        );
    }

    function isSuperMajority(uint256 participation) internal pure returns (bool) {
        return participation * 3 >= SYNC_COMMITTEE_SIZE * 2;
    }

    function computeSyncCommitteePeriod(uint64 slot) internal pure returns (uint64) {
        return slot / SLOTS_PER_EPOCH / EPOCHS_PER_SYNC_COMMITTEE_PERIOD;
    }
}