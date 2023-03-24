// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library LibGovernance {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.governance.storage");

    struct Storage {
        // nonce used for making administrative changes
        Counters.Counter administrativeNonce;
        // the set of active validators
        EnumerableSet.AddressSet membersSet;
        // governance message hashes we've executed
        mapping(bytes32 => bool) hashesUsed;
    }

    function governanceStorage() internal pure returns (Storage storage gs) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }

    /// @notice Adds/removes a validator from the member set
    function updateMember(address _account, bool _status) internal {
        Storage storage gs = governanceStorage();
        if (_status) {
            require(
                gs.membersSet.add(_account),
                "Governance: Account already added"
            );
        } else if (!_status) {
            require(
                gs.membersSet.length() > 1,
                "Governance: Would become memberless"
            );
            require(
                gs.membersSet.remove(_account),
                "Governance: Account is not a member"
            );
        }
    }

    /// @notice Returns true/false depending on whether a given address is member or not
    function isMember(address _member) internal view returns (bool) {
        Storage storage gs = governanceStorage();
        return gs.membersSet.contains(_member);
    }

    /// @notice Returns the count of the members
    function membersCount() internal view returns (uint256) {
        Storage storage gs = governanceStorage();
        return gs.membersSet.length();
    }

    /// @notice Returns the address of a member at a given index
    function memberAt(uint256 _index) internal view returns (address) {
        Storage storage gs = governanceStorage();
        return gs.membersSet.at(_index);
    }
}