// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "./LibStorage.sol";

/// @dev Storage helpers for the `Ownable` feature.
library LibOwnableStorage {
    /// @dev Storage bucket for this feature.
    struct Storage {
        // The owner of this contract.
        address owner;
        address admin;
    }

    /// @dev Get the storage bucket for this contract.
    function getStorage() internal pure returns (Storage storage stor) {
        uint256 storageSlot = LibStorage.getStorageSlot(
            LibStorage.StorageId.Ownable
        );

        assembly {
            stor.slot := storageSlot
        }
    }
}