// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../royalty/ICollectionRoyaltyReader.sol";

interface IERC721Listings {
    struct ListTokenInput {
        address erc721Address;
        uint256 tokenId;
        uint256 value;
        uint64 expireTimestamp;
        uint32 paymentTokenId;
    }

    struct DelistTokenInput {
        address erc721Address;
        uint256 tokenId;
    }

    struct PurchaseTokenInput {
        address erc721Address;
        uint256 tokenId;
        uint256 value;
    }

    struct PurchaseCheckResult {
        address erc721Address;
        uint256 tokenId;
        bool isValid;
        string message;
    }

    struct RemoveExpiredListingInput {
        address erc721Address;
        uint256 tokenId;
    }

    struct Listing {
        uint256 tokenId;
        uint256 value;
        address seller;
        uint64 expireTimestamp;
        uint32 paymentTokenId;
    }

    struct FundReceiver {
        address payable account;
        uint256 amount;
        address paymentToken;
    }

    enum Status {
        NOT_EXIST, // 0: listing doesn't exist
        ACTIVE, // 1: listing is active and valid
        TRADE_NOT_OPEN, // 2: trade not open
        EXPIRED, // 3: listing has expired
        TRANSFERRED, // 4: token has new owner
        DISAPPROVED, // 5: contract no longer approved to transfer token
        INVALID_PAYMENT_TOKEN // 6: payment token is not allowed
    }

    struct ListingStatus {
        uint256 tokenId;
        uint256 value;
        address seller;
        uint64 expireTimestamp;
        address paymentToken;
        Status status;
    }

    struct ERC721Listings {
        EnumerableSet.UintSet tokenIds;
        mapping(uint256 => Listing) listings;
    }

    event TokenListed(
        address indexed erc721Address,
        address indexed seller,
        uint256 tokenId,
        Listing listing,
        address sender // Token can be listed by the owner or a approved operator
    );
    event TokenDelisted(
        address indexed erc721Address,
        address indexed seller,
        uint256 tokenId,
        Listing listing,
        address sender
    );
    event TokenBought(
        address indexed erc721Address,
        address indexed buyer,
        uint256 tokenId,
        Listing listing,
        uint256 serviceFee,
        ICollectionRoyaltyReader.RoyaltyAmount[] royaltyInfo,
        address sender
    );

    event TokenListFailed(
        address indexed erc721Address,
        uint256 tokenId,
        string message,
        address sender
    );
    event TokenDelistFailed(
        address indexed erc721Address,
        uint256 tokenId,
        string message,
        address sender
    );
    event TokenPurchaseFailed(
        address indexed erc721Address,
        uint256 tokenId,
        string message,
        address sender
    );
    event EtherRetured(address indexed account, uint256 amount);

    event MarketSettingsContractUpdated(
        address previousMarketSettingsContract,
        address newMarketSettingsContract
    );

    /**
     * @dev List token for sale
     * @param erc721Address erc721 contract address
     * @param tokenId erc721 token ID
     * @param value sale price
     * @param expireTimestamp timestamp of when this listing will expire
     * @param paymentTokenId Payment token registry ID or 0 as native coin
     * Note:
     * paymentTokenId: When using 0 as payment token,
     * it refers to the native coin of the chain, e.g. BNB, FTM, etc.
     */
    function listToken(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        uint64 expireTimestamp,
        uint32 paymentTokenId
    ) external;

    /**
     * @dev List multiple tokens for sale
     * @param newListings erc721 tokens listing details
     */
    function listTokens(ListTokenInput[] calldata newListings) external;

    /**
     * @dev Delist token for sale
     * @param tokenId erc721 token Id
     */
    function delistToken(address erc721Address, uint256 tokenId) external;

    /**
     * @dev Delist multiple tokens for sale
     * @param listings erc721 tokens to delist
     */
    function delistTokens(DelistTokenInput[] calldata listings) external;

    /**
     * @dev Purchase token
     * @param tokenId erc721 token ID
     * @param value sale price
     * @param buyer of token
     * Note:
     * buyer: buyer is a required field because
     * sender can be a delegated operator, therefore buyer
     * address needs to be included
     */
    function purchaseToken(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        address buyer
    ) external payable;

    /**
     * @dev Pre-check purchase status before buying
     * @param tokens erc721 tokens to purchase
     * @param buyer of token
     * @param etherBalance balance of ether to be send for purchase
     */
    function checkTokensForPurchase(
        PurchaseTokenInput[] calldata tokens,
        address buyer,
        uint256 etherBalance
    ) external view returns (PurchaseCheckResult[] memory);

    /**
     * @dev Purchase multiple token
     * @param tokens  erc721 tokens to purchase
     */
    function purchaseTokens(
        PurchaseTokenInput[] calldata tokens,
        address buyer
    ) external payable;

    /**
     * @dev Remove expired listings
     * @param listings listings to remove
     * anyone can removed expired listings
     */
    function removeExpiredListings(
        RemoveExpiredListingInput[] calldata listings
    ) external;

    /**
     * @dev get current listing of a token
     * @param tokenId erc721 token Id
     * @return current valid listing or empty listing struct
     */
    function getTokenListing(
        address erc721Address,
        uint256 tokenId
    ) external view returns (ListingStatus memory);

    /**
     * @dev get count of listings
     */
    function numListingsOfCollection(
        address erc721Address
    ) external view returns (uint256);

    /**
     * @dev get current valid listings by size
     * @param from index to start
     * @param size size to query
     * @return listings and their status
     * This to help batch query when list gets big
     */
    function getListingsOfCollection(
        address erc721Address,
        uint256 from,
        uint256 size
    ) external view returns (ListingStatus[] memory);
}