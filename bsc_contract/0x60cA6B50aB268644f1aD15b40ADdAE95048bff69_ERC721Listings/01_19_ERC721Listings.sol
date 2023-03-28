// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../library/CollectionReader.sol";
import "../royalty/ICollectionRoyaltyReader.sol";
import "../payment-token/IPaymentTokenReader.sol";
import "../market-settings/IMarketSettings.sol";
import "./IERC721Listings.sol";
import "./OperatorDelegation.sol";

contract ERC721Listings is
    IERC721Listings,
    OperatorDelegation,
    ReentrancyGuard
{
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    constructor(address marketSettings_) {
        _marketSettings = IMarketSettings(marketSettings_);
        _paymentTokenRegistry = IPaymentTokenReader(
            _marketSettings.paymentTokenRegistry()
        );
    }

    IMarketSettings private _marketSettings;
    IPaymentTokenReader private _paymentTokenRegistry;

    mapping(address => ERC721Listings) private _erc721Listings;

    /**
     * @dev See {IERC721Listings-listToken}.
     */
    function listToken(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        uint64 expireTimestamp,
        uint32 paymentTokenId
    ) external {
        address tokenOwner = CollectionReader.tokenOwner(
            erc721Address,
            tokenId
        );

        (bool isValid, string memory message) = _checkListAction(
            erc721Address,
            tokenId,
            value,
            expireTimestamp,
            paymentTokenId,
            tokenOwner
        );

        require(isValid, message);

        _listToken(
            erc721Address,
            tokenId,
            value,
            expireTimestamp,
            paymentTokenId,
            tokenOwner
        );
    }

    /**
     * @dev See {IERC721Listings-listTokens}.
     */
    function listTokens(ListTokenInput[] calldata newListings) external {
        for (uint256 i = 0; i < newListings.length; i++) {
            address erc721Address = newListings[i].erc721Address;
            uint256 tokenId = newListings[i].tokenId;
            uint256 value = newListings[i].value;
            uint64 expireTimestamp = newListings[i].expireTimestamp;
            uint32 paymentTokenId = newListings[i].paymentTokenId;
            address tokenOwner = CollectionReader.tokenOwner(
                erc721Address,
                tokenId
            );

            (bool isValid, string memory message) = _checkListAction(
                erc721Address,
                tokenId,
                value,
                expireTimestamp,
                paymentTokenId,
                tokenOwner
            );

            if (isValid) {
                _listToken(
                    erc721Address,
                    tokenId,
                    value,
                    expireTimestamp,
                    paymentTokenId,
                    tokenOwner
                );
            } else {
                emit TokenListFailed(
                    erc721Address,
                    tokenId,
                    message,
                    _msgSender()
                );
            }
        }
    }

    /**
     * @dev See {IERC721Listings-delistToken}.
     */
    function delistToken(address erc721Address, uint256 tokenId) external {
        (bool isValid, string memory message) = _checkDelistAction(
            erc721Address,
            tokenId
        );

        require(isValid, message);

        _delistToken(erc721Address, tokenId);
    }

    /**
     * @dev See {IERC721Listings-delistTokens}.
     */
    function delistTokens(DelistTokenInput[] calldata listings) external {
        for (uint256 i; i < listings.length; i++) {
            address erc721Address = listings[i].erc721Address;
            uint256 tokenId = listings[i].tokenId;

            (bool isValid, string memory message) = _checkDelistAction(
                erc721Address,
                tokenId
            );

            if (isValid) {
                _delistToken(erc721Address, tokenId);
            } else {
                emit TokenDelistFailed(
                    erc721Address,
                    tokenId,
                    message,
                    _msgSender()
                );
            }
        }
    }

    /**
     * @dev See {IERC721Listings-purchaseToken}.
     * Must have a valid listing
     * msg.sender must not the owner of token
     * contract balance must be at least sell price plus fees
     */
    function purchaseToken(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        address buyer
    ) external payable {
        require(
            buyer == _msgSender() || isApprovedOperator(buyer, _msgSender()),
            "sender not buyer or approved operator"
        );

        Listing memory listing = _erc721Listings[erc721Address].listings[
            tokenId
        ];

        (bool isValid, string memory message) = _checkPurchaseAction(
            erc721Address,
            listing,
            value,
            buyer,
            msg.value
        );

        require(isValid, message);

        uint256 fundSpent = _purchaseToken(erc721Address, listing, buyer);

        // If any Ether remains after transfers, return it to the sender.
        if (listing.paymentTokenId == 0) {
            uint256 etherRemaining = msg.value - fundSpent;
            if (etherRemaining > 0) {
                Address.sendValue(payable(buyer), etherRemaining);
                emit EtherRetured(buyer, etherRemaining);
            }
        }
    }

    /**
     * @dev See {IERC721Listings-checkTokensForPurchase}.
     */
    function checkTokensForPurchase(
        PurchaseTokenInput[] calldata tokens,
        address buyer,
        uint256 etherBalance
    ) external view returns (PurchaseCheckResult[] memory checkResults) {
        checkResults = new PurchaseCheckResult[](tokens.length);

        for (uint256 i; i < tokens.length; i++) {
            address erc721Address = tokens[i].erc721Address;
            uint256 tokenId = tokens[i].tokenId;
            uint256 value = tokens[i].value;

            Listing memory listing = _erc721Listings[tokens[i].erc721Address]
                .listings[tokenId];

            (bool isValid, string memory message) = _checkPurchaseAction(
                erc721Address,
                listing,
                value,
                buyer,
                etherBalance
            );
            if (isValid) {
                checkResults[i] = PurchaseCheckResult(
                    erc721Address,
                    listing.tokenId,
                    true,
                    "valid"
                );
            } else {
                checkResults[i] = PurchaseCheckResult(
                    erc721Address,
                    listing.tokenId,
                    false,
                    message
                );
            }
        }
    }

    /**
     * @dev See {IERC721Listings-purchaseTokens}.
     */
    function purchaseTokens(
        PurchaseTokenInput[] calldata tokens,
        address buyer
    ) external payable {
        require(
            buyer == _msgSender() || isApprovedOperator(buyer, _msgSender()),
            "sender not buyer or approved operator"
        );

        uint256 etherRemaining = msg.value;

        for (uint256 i; i < tokens.length; i++) {
            address erc721Address = tokens[i].erc721Address;
            uint256 tokenId = tokens[i].tokenId;
            uint256 value = tokens[i].value;

            Listing memory listing = _erc721Listings[tokens[i].erc721Address]
                .listings[tokenId];

            (bool isValid, string memory message) = _checkPurchaseAction(
                erc721Address,
                listing,
                value,
                buyer,
                etherRemaining
            );
            if (isValid) {
                uint256 fundSpent = _purchaseToken(
                    erc721Address,
                    listing,
                    buyer
                );

                if (listing.paymentTokenId == 0) {
                    etherRemaining -= fundSpent;
                }
            } else {
                emit TokenPurchaseFailed(
                    erc721Address,
                    tokenId,
                    message,
                    _msgSender()
                );
            }
        }

        if (etherRemaining > 0) {
            Address.sendValue(payable(buyer), etherRemaining);
            emit EtherRetured(buyer, etherRemaining);
        }
    }

    /**
     * @dev See {IERC721Listings-removeExpiredListings}.
     */
    function removeExpiredListings(
        RemoveExpiredListingInput[] calldata listings
    ) external {
        for (uint256 i = 0; i < listings.length; i++) {
            address erc721Address = listings[i].erc721Address;
            uint256 tokenId = listings[i].tokenId;
            Listing memory listing = _erc721Listings[erc721Address].listings[
                tokenId
            ];

            if (
                listing.expireTimestamp != 0 &&
                listing.expireTimestamp <= block.timestamp
            ) {
                _removeListing(erc721Address, tokenId);
            }
        }
    }

    /**
     * @dev check if listing action is valid
     * if not valid, return the reason
     */
    function _checkListAction(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        uint64 expireTimestamp,
        uint32 paymentTokenId,
        address tokenOwner
    ) private view returns (bool isValid, string memory message) {
        isValid = false;

        if (!_marketSettings.isCollectionTradingEnabled(erc721Address)) {
            message = "trading is not open";
            return (isValid, message);
        }
        if (value == 0) {
            message = "price cannot be 0";
            return (isValid, message);
        }
        if (
            expireTimestamp - block.timestamp <
            _marketSettings.actionTimeOutRangeMin()
        ) {
            message = "expire time below minimum";
            return (isValid, message);
        }
        if (
            expireTimestamp - block.timestamp >
            _marketSettings.actionTimeOutRangeMax()
        ) {
            message = "expire time above maximum";
            return (isValid, message);
        }
        if (
            tokenOwner != _msgSender() &&
            !isApprovedOperator(tokenOwner, _msgSender())
        ) {
            message = "sender not owner or approved operator";
            return (isValid, message);
        }
        if (!_isAllowedPaymentToken(erc721Address, paymentTokenId)) {
            message = "payment token not enabled";
            return (isValid, message);
        }
        if (!_isApprovedToTransferToken(erc721Address, tokenId, tokenOwner)) {
            message = "transferred not approved";
            return (isValid, message);
        }

        isValid = true;
    }

    /**
     * @dev listing tokens and emit event
     */
    function _listToken(
        address erc721Address,
        uint256 tokenId,
        uint256 value,
        uint64 expireTimestamp,
        uint32 paymentTokenId,
        address tokenOwner
    ) private {
        Listing memory listing = Listing({
            tokenId: tokenId,
            value: value,
            seller: tokenOwner,
            expireTimestamp: expireTimestamp,
            paymentTokenId: paymentTokenId
        });

        _erc721Listings[erc721Address].listings[tokenId] = listing;
        _erc721Listings[erc721Address].tokenIds.add(tokenId);

        emit TokenListed(
            erc721Address,
            tokenOwner,
            tokenId,
            listing,
            _msgSender()
        );
    }

    /**
     * @dev check if delisting action is valid
     * if not valid, return the reason
     */
    function _checkDelistAction(
        address erc721Address,
        uint256 tokenId
    ) private view returns (bool isValid, string memory message) {
        isValid = false;

        Listing memory listing = _erc721Listings[erc721Address].listings[
            tokenId
        ];

        if (listing.seller == address(0)) {
            message = "listing does not exist";
            return (isValid, message);
        }

        address tokenOwner = CollectionReader.tokenOwner(
            erc721Address,
            tokenId
        );
        if (
            listing.seller != _msgSender() &&
            tokenOwner != _msgSender() &&
            !isApprovedOperator(listing.seller, _msgSender()) &&
            !isApprovedOperator(tokenOwner, _msgSender())
        ) {
            message = "sender not owner or approved operator";
            return (isValid, message);
        }

        isValid = true;
    }

    /**
     * @dev delist a token - remove token id record and remove listing from mapping
     * @param tokenId erc721 token Id
     */
    function _delistToken(address erc721Address, uint256 tokenId) private {
        Listing memory listing = _erc721Listings[erc721Address].listings[
            tokenId
        ];

        _removeListing(erc721Address, listing.tokenId);

        emit TokenDelisted(
            erc721Address,
            listing.seller,
            tokenId,
            listing,
            _msgSender()
        );
    }

    /**
     * @dev check if purchase action is valid
     * if not valid, return the reason
     */
    function _checkPurchaseAction(
        address erc721Address,
        Listing memory listing,
        uint256 value,
        address buyer,
        uint256 etherBalance
    ) private view returns (bool isValid, string memory message) {
        isValid = false;

        Status status = _getListingStatus(erc721Address, listing);
        if (status != Status.ACTIVE) {
            message = "listing is not valid";
            return (isValid, message);
        }
        if (value < listing.value) {
            message = "buying below asking price";
            return (isValid, message);
        }
        if (
            CollectionReader.tokenOwner(erc721Address, listing.tokenId) == buyer
        ) {
            message = "buyer cannot be owner";
            return (isValid, message);
        }

        if (listing.paymentTokenId == 0) {
            if (etherBalance < listing.value) {
                message = "insufficient fund";
                return (isValid, message);
            }
        } else {
            address paymentToken = _paymentTokenRegistry
                .getPaymentTokenAddressById(listing.paymentTokenId);
            if (
                IERC20(paymentToken).allowance(buyer, address(this)) <
                listing.value
            ) {
                message = "insufficient payment token allowance";
                return (isValid, message);
            }

            if (IERC20(paymentToken).balanceOf(buyer) < listing.value) {
                message = "insufficient payment token balance";
                return (isValid, message);
            }
        }

        isValid = true;
    }

    /**
     * @dev send fund and tokens, remove listing from storage, and emit event
     */
    function _purchaseToken(
        address erc721Address,
        Listing memory listing,
        address buyer
    ) private nonReentrant returns (uint256 fundSpent) {
        (
            FundReceiver[] memory fundReceivers,
            ICollectionRoyaltyReader.RoyaltyAmount[] memory royaltyInfo,
            uint256 serviceFee
        ) = _getFundReceiversOfListing(erc721Address, listing);

        fundSpent = _sendFundToReceivers(buyer, fundReceivers);

        // Send token to buyer
        IERC721(erc721Address).safeTransferFrom(
            listing.seller,
            buyer,
            listing.tokenId
        );

        _removeListing(erc721Address, listing.tokenId);

        emit TokenBought({
            erc721Address: erc721Address,
            buyer: buyer,
            tokenId: listing.tokenId,
            listing: listing,
            serviceFee: serviceFee,
            royaltyInfo: royaltyInfo,
            sender: _msgSender()
        });
    }

    function _removeListing(address erc721Address, uint256 tokenId) private {
        delete _erc721Listings[erc721Address].listings[tokenId];
        _erc721Listings[erc721Address].tokenIds.remove(tokenId);
    }

    /**
     * @dev get list of fund receivers, amount, and payment token
     * Note:
     * List of receivers
     * - Seller of token
     * - Service fee receiver
     * - royalty receivers
     */
    function _getFundReceiversOfListing(
        address erc721Address,
        Listing memory listing
    )
        private
        view
        returns (
            FundReceiver[] memory fundReceivers,
            ICollectionRoyaltyReader.RoyaltyAmount[] memory royaltyInfo,
            uint256 serviceFee
        )
    {
        address paymentToken = _paymentTokenRegistry.getPaymentTokenAddressById(
            listing.paymentTokenId
        );

        royaltyInfo = ICollectionRoyaltyReader(
            _marketSettings.royaltyRegsitry()
        ).royaltyInfo(erc721Address, listing.tokenId, listing.value);

        fundReceivers = new FundReceiver[](royaltyInfo.length + 2);

        uint256 amountToSeller = listing.value;
        for (uint256 i = 0; i < royaltyInfo.length; i++) {
            address royaltyReceiver = royaltyInfo[i].receiver;
            uint256 royaltyAmount = royaltyInfo[i].royaltyAmount;

            fundReceivers[i + 2] = FundReceiver({
                account: payable(royaltyReceiver),
                amount: royaltyAmount,
                paymentToken: paymentToken
            });

            amountToSeller -= royaltyAmount;
        }

        (address feeReceiver, uint256 feeAmount) = _marketSettings
            .serviceFeeInfo(listing.value);
        serviceFee = feeAmount;

        fundReceivers[1] = FundReceiver({
            account: payable(feeReceiver),
            amount: serviceFee,
            paymentToken: paymentToken
        });

        amountToSeller -= serviceFee;

        fundReceivers[0] = FundReceiver({
            account: payable(listing.seller),
            amount: amountToSeller,
            paymentToken: paymentToken
        });
    }

    /**
     * @dev Send ether to recipient
     * There's a possible occation where royalty receiver is not a payable address.
     * If send failed due to royalty receiver is not a payable address,
     * do not fail the transaction. Buyer and seller should not be victims
     * of bad royalty receiver addresses.
     * Instead, send the fund to the buyer
     */
    function _sendEther(
        address payable recipient,
        uint256 amount
    ) private returns (bool success) {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (success, ) = recipient.call{value: amount}("");
    }

    /**
     * @dev send payment token or ether
     */
    function _sendFund(
        address paymentToken,
        address from,
        address payable to,
        uint256 value
    ) private returns (bool success) {
        if (paymentToken == address(0)) {
            success = _sendEther(to, value);
        } else {
            IERC20(paymentToken).safeTransferFrom(from, to, value);
            success = true;
        }
    }

    /**
     * @dev send funds to a list of receivers
     */
    function _sendFundToReceivers(
        address from,
        FundReceiver[] memory fundReceivers
    ) private returns (uint256 fundSpent) {
        for (uint256 i; i < fundReceivers.length; i++) {
            bool success = _sendFund(
                fundReceivers[i].paymentToken,
                from,
                fundReceivers[i].account,
                fundReceivers[i].amount
            );

            if (success) {
                fundSpent += fundReceivers[i].amount;
            }
        }
    }

    /**
     * @dev See {IERC721Listings-getTokenListing}.
     */
    function getTokenListing(
        address erc721Address,
        uint256 tokenId
    ) public view returns (ListingStatus memory) {
        Listing memory listing = _erc721Listings[erc721Address].listings[
            tokenId
        ];
        Status status = _getListingStatus(erc721Address, listing);
        address paymentToken = _paymentTokenRegistry.getPaymentTokenAddressById(
            listing.paymentTokenId
        );

        return
            ListingStatus({
                tokenId: listing.tokenId,
                value: listing.value,
                seller: listing.seller,
                expireTimestamp: listing.expireTimestamp,
                paymentToken: paymentToken,
                status: status
            });
    }

    /**
     * @dev See {IERC721Listings-numListingsOfCollection}.
     */
    function numListingsOfCollection(
        address erc721Address
    ) public view returns (uint256) {
        return _erc721Listings[erc721Address].tokenIds.length();
    }

    /**
     * @dev See {IERC721Listings-getListingsOfCollection}.
     */
    function getListingsOfCollection(
        address erc721Address,
        uint256 from,
        uint256 size
    ) external view returns (ListingStatus[] memory listings) {
        uint256 listingsCount = numListingsOfCollection(erc721Address);

        if (from < listingsCount && size > 0) {
            uint256 querySize = size;
            if ((from + size) > listingsCount) {
                querySize = listingsCount - from;
            }
            listings = new ListingStatus[](querySize);
            for (uint256 i = 0; i < querySize; i++) {
                uint256 tokenId = _erc721Listings[erc721Address].tokenIds.at(
                    i + from
                );
                listings[i] = getTokenListing(erc721Address, tokenId);
            }
        }
    }

    /**
     * @dev address of market settings contract
     */
    function marketSettingsContract() external view returns (address) {
        return address(_marketSettings);
    }

    /**
     * @dev update market settings contract
     */
    function updateMarketSettingsContract(
        address newMarketSettingsContract
    ) external onlyOwner {
        address oldMarketSettingsContract = address(_marketSettings);
        _marketSettings = IMarketSettings(newMarketSettingsContract);

        emit MarketSettingsContractUpdated(
            oldMarketSettingsContract,
            newMarketSettingsContract
        );
    }

    /**
     * @dev check if payment token is allowed for a collection
     */
    function _isAllowedPaymentToken(
        address erc721Address,
        uint32 paymentTokenId
    ) private view returns (bool) {
        return
            paymentTokenId == 0 ||
            _paymentTokenRegistry.isAllowedPaymentToken(
                erc721Address,
                paymentTokenId
            );
    }

    /**
     * @dev check if a token or a collection if approved
     *  to be transferred by this contract
     */
    function _isApprovedToTransferToken(
        address erc721Address,
        uint256 tokenId,
        address account
    ) private view returns (bool) {
        return
            CollectionReader.isTokenApproved(erc721Address, tokenId) ||
            CollectionReader.isAllTokenApproved(
                erc721Address,
                account,
                address(this)
            );
    }

    /**
     * @dev get current status of a listing
     */
    function _getListingStatus(
        address erc721Address,
        Listing memory listing
    ) private view returns (Status) {
        if (listing.seller == address(0)) {
            return Status.NOT_EXIST;
        }
        if (!_marketSettings.isCollectionTradingEnabled(erc721Address)) {
            return Status.TRADE_NOT_OPEN;
        }
        if (listing.expireTimestamp < block.timestamp) {
            return Status.EXPIRED;
        }
        if (
            CollectionReader.tokenOwner(erc721Address, listing.tokenId) !=
            listing.seller
        ) {
            return Status.TRANSFERRED;
        }
        if (
            !_isApprovedToTransferToken(
                erc721Address,
                listing.tokenId,
                listing.seller
            )
        ) {
            return Status.DISAPPROVED;
        }
        if (!_isAllowedPaymentToken(erc721Address, listing.paymentTokenId)) {
            return Status.INVALID_PAYMENT_TOKEN;
        }
        return Status.ACTIVE;
    }
}