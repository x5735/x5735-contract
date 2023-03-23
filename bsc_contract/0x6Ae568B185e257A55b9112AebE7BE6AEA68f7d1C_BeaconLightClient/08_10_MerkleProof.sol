// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Math.sol";

contract MerkleProof is Math {
    // Check if ``leaf`` at ``index`` verifies against the Merkle ``root`` and ``branch``.
    function isValidMerkleBranch(
        bytes32 leaf,
        bytes32[] memory branch,
        uint64 depth,
        uint64 index,
        bytes32 root
    ) internal pure returns (bool) {
        bytes32 value = leaf;
        for (uint i = 0; i < depth; ++i) {
            if ((index / (2**i)) % 2 == 1) {
                value = hashNode(branch[i], value);
            } else {
                value = hashNode(value, branch[i]);
            }
        }
        return value == root;
    }

    function merkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        uint len = leaves.length;
        if (len == 0) return bytes32(0);
        else if (len == 1) return hash(abi.encodePacked(leaves[0]));
        else if (len == 2) return hashNode(leaves[0], leaves[1]);
        uint bottomLength = getPowerOfTwoCeil(len);
        bytes32[] memory o = new bytes32[](bottomLength * 2);
        for (uint i = 0; i < len; ++i) {
            o[bottomLength + i] = leaves[i];
        }
        for (uint i = bottomLength - 1; i > 0; --i) {
            o[i] = hashNode(o[i * 2], o[i * 2 + 1]);
        }
        return o[1];
    }


    function hashNode(bytes32 left, bytes32 right)
        internal
        pure
        returns (bytes32)
    {
        return hash(abi.encodePacked(left, right));
    }

    function hash(bytes memory value) internal pure returns (bytes32) {
        return sha256(value);
    }
}