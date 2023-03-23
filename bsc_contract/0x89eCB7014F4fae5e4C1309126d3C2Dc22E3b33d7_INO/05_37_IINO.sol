// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IINO {
    error INO__Unauthorized();
    error INO__OnGoingCampaign();
    error INO__InsuficcientAmount();
    error INO__AllocationExceeded();
    error INO__ExternalCallFailed();
    error INO__UnsupportedPayment(address);
    error INO__CampaignEndedOrNotYetStarted();

    struct Campaign {
        uint64 start;
        uint32 limit; // user buy limit
        address nft;
        uint64 end;
        uint64 maxSupply;
        uint128 typeNFT;
        uint96 usdPrice;
        address[] payments;
    }

    struct Ticket {
        address paymentToken;
        uint256 campaignId;
        uint256 amount;
    }

    event Registered(
        address indexed user,
        address indexed erc721,
        uint256[] tokenIds,
        uint256 price
    );

    event Redeemed(
        address indexed buyer,
        uint256 indexed ticketId,
        address indexed paymentToken,
        uint256 total
    );

    event Received(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        bytes data
    );

    event NewCampaign(
        uint256 indexed campaignId,
        uint64 indexed startAt,
        uint64 indexed endAt
    );

    function ticketId(
        uint64 campaignId_,
        uint32 amount_
    ) external pure returns (uint256);

    function redeem(
        address user_,
        address token_,
        uint256 value_,
        uint256 ticketId_
    ) external;

    function setCampaign(
        uint256 campaignId_,
        Campaign calldata campaign_
    ) external;

    function paymentOf(
        uint256 campaignId_
    ) external view returns (address[] memory);

    function campaign(
        uint256 campaignId_
    ) external view returns (Campaign memory campaign_);
}