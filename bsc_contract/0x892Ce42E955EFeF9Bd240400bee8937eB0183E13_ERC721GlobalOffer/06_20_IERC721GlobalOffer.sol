// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../royalty/ICollectionRoyaltyReader.sol";

interface IERC721GlobalOffer {
    struct Offer {
        uint256 offerId;
        uint256 value;
        address from;
        uint256 amount;
        uint256 fulfilledAmount;
        uint64 expireTimestamp;
        uint32 paymentTokenId;
    }

    struct OfferStatus {
        uint256 offerId;
        uint256 value;
        address from;
        uint256 amount;
        uint256 fulfilledAmount;
        uint256 availableAmount;
        uint64 expireTimestamp;
        address paymentToken;
        Status status;
    }

    struct FundReceiver {
        address account;
        uint256 amount;
        address paymentToken;
    }

    struct RemoveExpiredOfferInput {
        address erc721Address;
        uint256 offerId;
    }

    enum Status {
        NOT_EXIST, // 0: offer doesn't exist
        ACTIVE, // 1: offer is active and valid
        TRADE_NOT_OPEN, // 2: trade not open
        EXPIRED, // 3: offer has expired
        INVALID_PAYMENT_TOKEN, // 4: payment token is not allowed
        INSUFFICIENT_BALANCE, // 5: insufficient payment token balance
        INSUFFICIENT_ALLOWANCE // 6: insufficient payment token allowance
    }

    struct CollectionOffers {
        EnumerableSet.UintSet offerIds;
        mapping(uint256 => Offer) offers;
    }

    event OfferCreated(
        address indexed erc721Address,
        address indexed from,
        Offer offer,
        address sender
    );
    event OfferCancelled(
        address indexed erc721Address,
        address indexed from,
        Offer offer,
        address sender
    );
    event OfferAccepted(
        address indexed erc721Address,
        address indexed seller,
        uint256 tokenId,
        Offer offer,
        uint256 serviceFee,
        ICollectionRoyaltyReader.RoyaltyAmount[] royaltyInfo,
        address sender
    );
    event AcceptOfferFailed(
        address indexed erc721Address,
        uint256 offerId,
        uint256 tokenId,
        string message,
        address sender
    );

    event MarketSettingsContractUpdated(
        address previousMarketSettingsContract,
        address newMarketSettingsContract
    );

    /**
     * @dev Create offer
     * @param value price in payment token
     * @param amount amount of tokens to get
     * @param expireTimestamp when would this offer expire
     * @param paymentTokenId Payment token registry ID for payment
     * @param bidder account placing the bid. required due to delegated operations are possible
     * paymentTokenId: When using 0 as payment token ID,
     * it refers to wrapped coin of the chain, e.g. WBNB, WFTM, etc.
     */
    function createOffer(
        address erc721Address,
        uint256 value,
        uint256 amount,
        uint64 expireTimestamp,
        uint32 paymentTokenId,
        address bidder
    ) external;

    /**
     * @dev Cancel offer
     * @param offerId global offer id to cancel
     */
    function cancelOffer(address erc721Address, uint256 offerId) external;

    /**
     * @dev Accept offer
     * @param offerId global offer id
     * @param tokenId token ID to accept offer
     */
    function acceptOffer(
        address erc721Address,
        uint256 offerId,
        uint256 tokenId
    ) external;

    /**
     * @dev Accept offer for multiple tokens
     * @param offerId global offer id
     * @param tokenIds token IDs to accept offer
     */
    function batchAcceptOffer(
        address erc721Address,
        uint256 offerId,
        uint256[] calldata tokenIds
    ) external;

    /**
     * @dev Remove expired offers
     * @param offers global offers to remove
     */
    function removeExpiredOffers(
        RemoveExpiredOfferInput[] calldata offers
    ) external;

    /**
     * @dev get count of offer(s)
     */
    function numOffers(address erc721Address) external view returns (uint256);

    /**
     * @dev get all valid offers of a collection
     * @param offerId global offer id
     * @return Offer status
     */
    function getOffer(
        address erc721Address,
        uint256 offerId
    ) external view returns (OfferStatus memory);

    /**
     * @dev get all valid offers of a collection
     * @param from index to start
     * @param size size to query
     * @return Offers of a collection
     */
    function getOffers(
        address erc721Address,
        uint256 from,
        uint256 size
    ) external view returns (OfferStatus[] memory);
}