// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../library/CollectionReader.sol";
import "../royalty/ICollectionRoyaltyReader.sol";
import "../payment-token/IPaymentTokenReader.sol";
import "../market-settings/IMarketSettings.sol";
import "./IERC721GlobalOffer.sol";
import "./OperatorDelegation.sol";

contract ERC721GlobalOffer is
    IERC721GlobalOffer,
    OperatorDelegation,
    ReentrancyGuard
{
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

    uint256 private _currentOfferId = 0;

    mapping(address => CollectionOffers) private _erc721Offers;

    /**
     * @dev See {IERC721GlobalOffer-createOffer}.
     */
    function createOffer(
        address erc721Address,
        uint256 value,
        uint256 amount,
        uint64 expireTimestamp,
        uint32 paymentTokenId,
        address bidder
    ) external {
        require(
            _marketSettings.isCollectionTradingEnabled(erc721Address),
            "trade is not open"
        );
        require(value > 0, "offer value cannot be 0");
        require(amount > 0, "offer amount cannot be 0");
        require(
            expireTimestamp - block.timestamp >=
                _marketSettings.actionTimeOutRangeMin(),
            "expire time below minimum"
        );
        require(
            expireTimestamp - block.timestamp <=
                _marketSettings.actionTimeOutRangeMax(),
            "expire time above maximum"
        );
        require(
            _isAllowedPaymentToken(erc721Address, paymentTokenId),
            "payment token not enabled"
        );
        require(
            bidder == _msgSender() || isApprovedOperator(bidder, _msgSender()),
            "sender not bidder or approved operator"
        );
        address paymentToken = _getPaymentTokenAddress(paymentTokenId);
        uint256 totalValue = value * amount;
        require(
            IERC20(paymentToken).balanceOf(bidder) >= totalValue,
            "insufficient balance"
        );
        require(
            IERC20(paymentToken).allowance(bidder, address(this)) >= totalValue,
            "insufficient allowance"
        );

        uint256 offerId = _currentOfferId;

        Offer memory offer = Offer({
            offerId: offerId,
            value: value,
            from: bidder,
            amount: amount,
            fulfilledAmount: 0,
            expireTimestamp: expireTimestamp,
            paymentTokenId: paymentTokenId
        });

        _erc721Offers[erc721Address].offerIds.add(offerId);
        _erc721Offers[erc721Address].offers[offerId] = offer;

        _currentOfferId++;

        emit OfferCreated(erc721Address, bidder, offer, _msgSender());
    }

    /**
     * @dev See {IERC721GlobalOffer-cancelOffer}.
     */
    function cancelOffer(address erc721Address, uint256 offerId) external {
        Offer memory offer = _erc721Offers[erc721Address].offers[offerId];

        require(offer.from != address(0), "offer does not exist");

        require(
            offer.from == _msgSender() ||
                isApprovedOperator(offer.from, _msgSender()),
            "sender not bidder or approved operator"
        );

        _removeOffer(erc721Address, offerId);

        emit OfferCancelled(erc721Address, offer.from, offer, _msgSender());
    }

    /**
     * @dev See {IERC721GlobalOffer-acceptOffer}.
     */
    function acceptOffer(
        address erc721Address,
        uint256 offerId,
        uint256 tokenId
    ) external {
        address tokenOwner = CollectionReader.tokenOwner(
            erc721Address,
            tokenId
        );

        Offer memory offer = _erc721Offers[erc721Address].offers[offerId];

        (bool isValid, string memory message) = _checkAcceptOfferAction(
            erc721Address,
            offer,
            tokenId,
            tokenOwner
        );

        require(isValid, message);

        _acceptOffer(erc721Address, offer, tokenId, tokenOwner);
    }

    /**
     * @dev See {IERC721GlobalOffer-batchAcceptOffer}.
     */
    function batchAcceptOffer(
        address erc721Address,
        uint256 offerId,
        uint256[] calldata tokenIds
    ) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address tokenOwner = CollectionReader.tokenOwner(
                erc721Address,
                tokenId
            );

            Offer memory offer = _erc721Offers[erc721Address].offers[offerId];

            (bool isValid, string memory message) = _checkAcceptOfferAction(
                erc721Address,
                offer,
                tokenId,
                tokenOwner
            );

            if (isValid) {
                _acceptOffer(erc721Address, offer, tokenId, tokenOwner);
            } else {
                emit AcceptOfferFailed(
                    erc721Address,
                    offerId,
                    tokenId,
                    message,
                    _msgSender()
                );
            }
        }
    }

    /**
     * @dev See {IERC721GlobalOffer-removeExpiredOffers}.
     */
    function removeExpiredOffers(
        RemoveExpiredOfferInput[] calldata offers
    ) external {
        for (uint256 i = 0; i < offers.length; i++) {
            address erc721Address = offers[i].erc721Address;
            uint256 offerId = offers[i].offerId;
            Offer memory offer = _erc721Offers[erc721Address].offers[offerId];

            if (
                offer.expireTimestamp != 0 &&
                offer.expireTimestamp <= block.timestamp
            ) {
                _removeOffer(erc721Address, offerId);
            }
        }
    }

    /**
     * @dev check if accept action is valid
     * if not valid, return the reason
     */
    function _checkAcceptOfferAction(
        address erc721Address,
        Offer memory offer,
        uint256 tokenId,
        address tokenOwner
    ) private view returns (bool isValid, string memory message) {
        isValid = false;

        (Status status, ) = _getOfferStatus(erc721Address, offer);
        if (status != Status.ACTIVE) {
            message = "offer is not valid";
            return (isValid, message);
        }

        if (
            tokenOwner != _msgSender() &&
            !isApprovedOperator(tokenOwner, _msgSender())
        ) {
            message = "sender not owner or approved operator";
            return (isValid, message);
        }

        if (!_isApprovedToTransferToken(erc721Address, tokenId, tokenOwner)) {
            message = "transferred not approved";
            return (isValid, message);
        }

        isValid = true;
    }

    /**
     * @dev accept an offer of a single token
     */
    function _acceptOffer(
        address erc721Address,
        Offer memory offer,
        uint256 tokenId,
        address tokenOwner
    ) private nonReentrant {
        (
            FundReceiver[] memory fundReceivers,
            ICollectionRoyaltyReader.RoyaltyAmount[] memory royaltyInfo,
            uint256 serviceFee
        ) = _getFundReceiversOfOffer(erc721Address, offer, tokenId, tokenOwner);

        _sendFundToReceivers(offer.from, fundReceivers);

        IERC721(erc721Address).safeTransferFrom({
            from: tokenOwner,
            to: offer.from,
            tokenId: tokenId
        });

        offer.fulfilledAmount = offer.fulfilledAmount + 1;

        if (offer.fulfilledAmount == offer.amount) {
            _removeOffer(erc721Address, offer.offerId);
        } else {
            _erc721Offers[erc721Address].offers[offer.offerId] = offer;
        }

        emit OfferAccepted({
            erc721Address: erc721Address,
            seller: tokenOwner,
            tokenId: tokenId,
            offer: offer,
            serviceFee: serviceFee,
            royaltyInfo: royaltyInfo,
            sender: _msgSender()
        });
    }

    /**
     * @dev get list of fund receivers, amount, and payment token
     * Note:
     * List of receivers
     * - Seller of token
     * - Service fee receiver
     * - royalty receivers
     */
    function _getFundReceiversOfOffer(
        address erc721Address,
        Offer memory offer,
        uint256 tokenId,
        address tokenOwner
    )
        private
        view
        returns (
            FundReceiver[] memory fundReceivers,
            ICollectionRoyaltyReader.RoyaltyAmount[] memory royaltyInfo,
            uint256 serviceFee
        )
    {
        address paymentToken = _getPaymentTokenAddress(offer.paymentTokenId);

        royaltyInfo = ICollectionRoyaltyReader(
            _marketSettings.royaltyRegsitry()
        ).royaltyInfo(erc721Address, tokenId, offer.value);

        fundReceivers = new FundReceiver[](royaltyInfo.length + 2);

        uint256 amountToSeller = offer.value;
        for (uint256 i = 0; i < royaltyInfo.length; i++) {
            address royaltyReceiver = royaltyInfo[i].receiver;
            uint256 royaltyAmount = royaltyInfo[i].royaltyAmount;

            fundReceivers[i + 2] = FundReceiver({
                account: royaltyReceiver,
                amount: royaltyAmount,
                paymentToken: paymentToken
            });

            amountToSeller -= royaltyAmount;
        }

        (address feeReceiver, uint256 feeAmount) = _marketSettings
            .serviceFeeInfo(offer.value);
        serviceFee = feeAmount;

        fundReceivers[1] = FundReceiver({
            account: feeReceiver,
            amount: serviceFee,
            paymentToken: paymentToken
        });

        amountToSeller -= serviceFee;

        fundReceivers[0] = FundReceiver({
            account: tokenOwner,
            amount: amountToSeller,
            paymentToken: paymentToken
        });
    }

    /**
     * @dev map payment token address
     * 0 is mapped to wrapped ether address.
     * For a given chain, wrapped ether represent it's
     * corresponding wrapped coin. e.g. WBNB for BSC, WFTM for FTM
     */
    function _getPaymentTokenAddress(
        uint32 paymentTokenId
    ) private view returns (address paymentToken) {
        if (paymentTokenId == 0) {
            paymentToken = _marketSettings.wrappedEther();
        } else {
            paymentToken = _paymentTokenRegistry.getPaymentTokenAddressById(
                paymentTokenId
            );
        }
    }

    /**
     * @dev send payment token
     */
    function _sendFund(
        address paymentToken,
        address from,
        address to,
        uint256 value
    ) private {
        require(paymentToken != address(0), "payment token can't be 0 address");
        IERC20(paymentToken).safeTransferFrom(from, to, value);
    }

    /**
     * @dev send funds to a list of receivers
     */
    function _sendFundToReceivers(
        address from,
        FundReceiver[] memory fundReceivers
    ) private {
        for (uint256 i; i < fundReceivers.length; i++) {
            _sendFund(
                fundReceivers[i].paymentToken,
                from,
                fundReceivers[i].account,
                fundReceivers[i].amount
            );
        }
    }

    /**
     * @dev See {IERC721GlobalOffer-numOffers}.
     */
    function numOffers(address erc721Address) public view returns (uint256) {
        return _erc721Offers[erc721Address].offerIds.length();
    }

    /**
     * @dev See {IERC721GlobalOffer-getOffer}.
     */
    function getOffer(
        address erc721Address,
        uint256 offerId
    ) public view returns (OfferStatus memory) {
        Offer memory offer = _erc721Offers[erc721Address].offers[offerId];
        (Status status, uint256 availableAmount) = _getOfferStatus(
            erc721Address,
            offer
        );
        address paymentToken = _paymentTokenRegistry.getPaymentTokenAddressById(
            offer.paymentTokenId
        );

        return
            OfferStatus({
                offerId: offer.offerId,
                value: offer.value,
                from: offer.from,
                amount: offer.amount,
                fulfilledAmount: offer.fulfilledAmount,
                availableAmount: availableAmount,
                expireTimestamp: offer.expireTimestamp,
                paymentToken: paymentToken,
                status: status
            });
    }

    /**
     * @dev See {IERC721GlobalOffer-getOffers}.
     */
    function getOffers(
        address erc721Address,
        uint256 from,
        uint256 size
    ) external view returns (OfferStatus[] memory offers) {
        uint256 offersCount = numOffers(erc721Address);

        if (from < offersCount && size > 0) {
            uint256 querySize = size;
            if ((from + size) > offersCount) {
                querySize = offersCount - from;
            }
            offers = new OfferStatus[](querySize);
            for (uint256 i = 0; i < querySize; i++) {
                uint256 offerId = _erc721Offers[erc721Address].offerIds.at(
                    i + from
                );

                OfferStatus memory offer = getOffer(erc721Address, offerId);

                offers[i] = offer;
            }
        }
    }

    /**
     * @dev Get offer current status
     */
    function _getOfferStatus(
        address erc721Address,
        Offer memory offer
    ) private view returns (Status, uint256) {
        if (offer.from == address(0)) {
            return (Status.NOT_EXIST, 0);
        }
        if (!_marketSettings.isCollectionTradingEnabled(erc721Address)) {
            return (Status.TRADE_NOT_OPEN, 0);
        }
        if (offer.expireTimestamp < block.timestamp) {
            return (Status.EXPIRED, 0);
        }
        if (!_isAllowedPaymentToken(erc721Address, offer.paymentTokenId)) {
            return (Status.INVALID_PAYMENT_TOKEN, 0);
        }
        address paymentToken = _getPaymentTokenAddress(offer.paymentTokenId);
        uint256 paymentTokenBalance = IERC20(paymentToken).balanceOf(
            offer.from
        );
        uint256 paymentTokenAllowance = IERC20(paymentToken).allowance(
            offer.from,
            address(this)
        );
        if (paymentTokenBalance < offer.value) {
            return (Status.INSUFFICIENT_BALANCE, 0);
        }
        if (paymentTokenAllowance < offer.value) {
            return (Status.INSUFFICIENT_ALLOWANCE, 0);
        }

        uint256 availableAmount = Math.min(
            Math.min(paymentTokenAllowance, paymentTokenBalance) / offer.value,
            offer.amount - offer.fulfilledAmount
        );
        return (Status.ACTIVE, availableAmount);
    }

    /**
     * @dev remove a offer of a bidder
     * @param offerId global offer id
     */
    function _removeOffer(address erc721Address, uint256 offerId) private {
        delete _erc721Offers[erc721Address].offers[offerId];
        _erc721Offers[erc721Address].offerIds.remove(offerId);
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
}