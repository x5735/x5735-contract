// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "./libraries/LibGovernance.sol";

/**
 * @notice Provides modifiers for securing methods behind a governance vote
 */
abstract contract Governable {
    using Counters for Counters.Counter;

    /**
     * @notice Verifies the message hash against the signatures. Requires a majority.
     * @param _ethHash hash to verify
     * @param _signatures governance hash signatures
     */
    function onlyConsensus(bytes32 _ethHash, bytes[] calldata _signatures) internal view {
        uint256 members = LibGovernance.membersCount();
        require(_signatures.length <= members, "Governance: Invalid number of signatures");
        require(_signatures.length > members / 2, "Governance: Invalid number of signatures");

        address[] memory signers = new address[](_signatures.length);
        for (uint256 i = 0; i < _signatures.length;) {
            address signer = ECDSA.recover(_ethHash, _signatures[i]);
            require(LibGovernance.isMember(signer), "Governance: invalid signer");
            for (uint256 j = 0; j < i;) {
                require(signer != signers[j], "Governance: duplicate signatures");
                unchecked { j += 1; }
            }
            signers[i] = signer;
            unchecked { i += 1; }
        }
    }

    /**
     * @notice Verifies the message hash against the signatures. Requires a majority. Burns a nonce.
     * @param _ethHash hash to verify
     * @param _signatures governance hash signatures
     */
    modifier onlyConsensusNonce(bytes32 _ethHash, bytes[] calldata _signatures) {
        onlyConsensus(_ethHash, _signatures);
        LibGovernance.governanceStorage().administrativeNonce.increment();
        _;
    }

    /**
     * @notice Verifies the message hash against the signatures. Requires a majority. Burns the hash.
     * @param _ethHash hash to verify
     * @param _signatures governance hash signatures
     */
    modifier onlyConsensusHash(bytes32 _ethHash, bytes[] calldata _signatures) {
        LibGovernance.Storage storage gs = LibGovernance.governanceStorage();
        require(!gs.hashesUsed[_ethHash], "Governance: message hash already used");
        gs.hashesUsed[_ethHash] = true;
        onlyConsensus(_ethHash, _signatures);
        _;
    }
}