// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

interface IAuctionFeature {
    event CreateAuction(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid
    );

    event NewBid(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address bidder,
        uint256 price
    );

    event ClaimNft(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address buyer,
        uint256 price
    );

    event CancelSellAuction(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address owner
    );

    event LoseBid(uint256 indexed idOnMarket, address user, uint256 returnBid);
    event NewAuctionPack(uint256 packId, uint256[] storageIdOnMarket);

    function saleAuction(
        uint256 _tokenId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid,
        address _contractHold,
        address _factory
    ) external;

    function batchSaleAuction(
        uint256[] memory _tokenIds,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid,
        address _contractHold,
        address _factory
    ) external;

    function getListingItemInOnePackAuction(uint256 _pack)
        external
        view
        returns (uint256[] memory);

    function Bid(uint256 _idOnMarket, uint256 _price) external;

    function claimNft(uint256 _idOnMarket) external;

    function batchClaimNft(uint256 pack, uint256[] memory _idsOnMarket)
        external;

    function cancelSellAuction(uint256 _idOnMarket) external;

    function batchCancelSellAuction(
        uint256 packId,
        uint256[] memory idsOnMarket
    ) external;
}