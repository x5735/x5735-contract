// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "./LibStorage.sol";

/// @dev Storage helpers for `NativeOrdersFeature`.
library LibAuctionStorage {
    struct MarketAuctionItem {
        uint256 idOnMarket;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        uint256 minBid;
        uint256 maxBid;
        uint256 latestBid;
        address latestUserBid;
        address contractHold;
        address nftContract;
        address seller;
        address owner;
        bool sold;
        uint256 packId;
    }

    struct PackData {
        bool isPackSold;
        uint256 fromId;
        uint256 endId;
    }
    /// @dev Storage bucket for this feature.
    struct Storage {
        uint256 _itemIds;
        uint256 _itemsSold;
        mapping(uint256 => MarketAuctionItem) idToMarketItem;
        uint256 _idPacks;
        mapping(uint256 => PackData) packData;
    }

    /// @dev Get the storage bucket for this contract.
    function getStorage() internal pure returns (Storage storage stor) {
        uint256 storageSlot = LibStorage.getStorageSlot(
            LibStorage.StorageId.Auction
        );
        // Dip into assembly to change the slot pointed to by the local
        // variable `stor`.
        // See https://solidity.readthedocs.io/en/v0.6.8/assembly.html?highlight=slot#access-to-external-variables-functions-and-libraries
        assembly {
            stor.slot := storageSlot
        }
    }
}