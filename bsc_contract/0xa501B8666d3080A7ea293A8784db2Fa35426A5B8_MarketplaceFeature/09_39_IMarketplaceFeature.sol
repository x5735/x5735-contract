// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "../../storage/LibMarketplaceStorage.sol";

interface IMarketplaceFeature {
    event CreateMarketItem(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    event BuyMarketItem(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address owner,
        uint256 price
    );

    event CancelSell(
        uint256 indexed idOnMarket,
        uint256 tokenId,
        address nftContract,
        address seller,
        address owner
    );

    event NewPack(uint256 pack, uint256[] idsOnMarket);

    function batchSale(
        uint256[] memory _tokenId,
        address _factoryAddress,
        uint256 _priceItem,
        address _contractHold
    ) external;

    enum BATCH_BUY_TYPE {
        BUY_TOTAL,
        BUY_EACH
    }

    function Sale(
        uint256 _tokenId,
        address _factoryAddress,
        uint256 _priceItem,
        address _contractHold
    ) external;

    function getIsPackSold(uint256 _pack) external view returns (bool);

    function Buy(uint256 _idOnMarket) external;

    function batchBuy(
        uint256 packId,
        uint256[] memory _idsOnMarket,
        BATCH_BUY_TYPE buyType,
        uint256 _price
    ) external;

    function cancelSell(uint256 _idOnMarket) external;

    function getListingItemInOnePack(uint256 _pack)
        external
        view
        returns (uint256[] memory);

    function getPack(uint256 pack)
        external
        view
        returns (LibMarketplaceStorage.PackData memory);

    function getIdOnMarket(uint256 id)
        external
        view
        returns (LibMarketplaceStorage.MarketItem memory);

    function batchCancelSell(uint256 packId, uint256[] memory _idOnMarket)
        external;
}