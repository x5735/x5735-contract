// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    IERC721PermitUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/IERC721PermitUpgradeable.sol";

interface IMarketplace {
    error Marketplace__Expired();
    error Marketplace__UnsupportedNFT();
    error Marketplace__ExecutionFailed();
    error Marketplace__InvalidSignature();
    error Marketplace__UnsupportedPayment();

    struct Seller {
        uint256 tokenId;
        uint256 deadline;
        uint256 unitPrice;
        address payment;
        IERC721PermitUpgradeable nft;
        bytes signature;
    }

    struct Buyer {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    event ProtocolFeeUpdated(
        address indexed operator,
        uint256 indexed feeFraction
    );

    event Redeemed(
        address indexed buyer,
        address indexed seller,
        Seller sellerItem
    );

    event TokensWhitelisted(address indexed operator, address[] tokens);

    function nonces(address account_) external view returns (uint256);

    function setProtocolFee(uint256 feeFraction_) external;

    function redeem(
        uint256 deadline_,
        Buyer calldata buyer_,
        Seller calldata seller_,
        bytes calldata signature_
    ) external payable;
}