// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "./LibStorage.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../../op-ref.sol";

/// @dev Storage helpers for `NativeOrdersFeature`.
library LibNativeOrdersStorage {
    struct MarketItem {
        uint256 idOnMarket;
        uint256 tokenId;
        address contractHold;
        address nftContract;
        address seller;
        address owner;
        uint256 price;
        bool sold;
    }
    /// @dev Storage bucket for this feature.
    struct Storage {
        address feeAddress;
        IERC20 MainToken;
        OPV_REF RefContract;
        uint256 feeCreator;
        uint256 feeMarket;
        uint256 feeRef;
        mapping(address => bool) AllFactoryBasic;
        mapping(address => bool) AllFactoryVip;
        mapping(address => bool) blackListFee;
    }

    /// @dev Get the storage bucket for this contract.
    function getStorage() internal pure returns (Storage storage stor) {
        uint256 storageSlot = LibStorage.getStorageSlot(
            LibStorage.StorageId.NativeProxy
        );
        // Dip into assembly to change the slot pointed to by the local
        // variable `stor`.
        // See https://solidity.readthedocs.io/en/v0.6.8/assembly.html?highlight=slot#access-to-external-variables-functions-and-libraries
        assembly {
            stor.slot := storageSlot
        }
    }
}