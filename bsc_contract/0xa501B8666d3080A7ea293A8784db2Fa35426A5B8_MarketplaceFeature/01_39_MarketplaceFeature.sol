// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../op-factory.sol";
import "../../op-hold.sol";
import "../../op-ref.sol";
import "./interfaces/IMarketplaceFeature.sol";

import "./NativeMarketFeature.sol";
import "../storage/LibMarketplaceStorage.sol";
import "../storage/LibOwnableStorage.sol";

import "../FixinCommon.sol";

contract MarketplaceFeature is
    ReentrancyGuard,
    IMarketplaceFeature,
    FixinCommon
{
    modifier isFactory(address _factory) {
        require(
            LibNativeOrdersStorage.getStorage().AllFactoryBasic[_factory] ==
                true ||
                LibNativeOrdersStorage.getStorage().AllFactoryVip[_factory] ==
                true,
            "Is Not Factory"
        );
        _;
    }

    function batchSale(
        uint256[] memory _tokenIds,
        address _factoryAddress,
        uint256 _priceItem,
        address _contractHold
    ) public override nonReentrant {
        LibMarketplaceStorage.getStorage()._idPacks++;
        uint256 packIndex = LibMarketplaceStorage.getStorage()._idPacks;
        uint256[] memory storageIdOnMarket = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            storageIdOnMarket[i] = _sale(
                _tokenIds[i],
                _factoryAddress,
                _priceItem,
                _contractHold,
                packIndex
            );
        }

        LibMarketplaceStorage.getStorage().packData[
            packIndex
        ] = LibMarketplaceStorage.PackData(
            false,
            storageIdOnMarket[0],
            storageIdOnMarket[_tokenIds.length - 1]
        );

        emit NewPack(packIndex, storageIdOnMarket);
    }

    function _sale(
        uint256 _tokenId,
        address _factoryAddress,
        uint256 _priceItem,
        address _contractHold,
        uint256 _packId
    ) private isFactory(_factoryAddress) returns (uint256) {
        LibMarketplaceStorage.getStorage()._itemIds++;
        uint256 idOnMarket = LibMarketplaceStorage.getStorage()._itemIds;

        LibMarketplaceStorage.getStorage().idToMarketItem[
                idOnMarket
            ] = LibMarketplaceStorage.MarketItem(
            idOnMarket,
            _tokenId,
            _contractHold,
            _factoryAddress,
            msg.sender,
            address(0),
            _priceItem,
            false,
            _packId
        );

        OPVFactory(_factoryAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit CreateMarketItem(
            idOnMarket,
            _tokenId,
            _factoryAddress,
            msg.sender,
            address(0),
            _priceItem,
            false
        );

        return idOnMarket;
    }

    /* Places an item for sale on the marketplace */
    function Sale(
        uint256 _tokenId,
        address _factoryAddress,
        uint256 _priceItem,
        address _contractHold
    ) public override nonReentrant {
        _sale(_tokenId, _factoryAddress, _priceItem, _contractHold, 0);
    }

    function Buy(uint256 _idOnMarket) public override nonReentrant {
        _buy(_idOnMarket);
    }

    function batchBuy(
        uint256 packId,
        uint256[] memory _idsOnMarket,
        BATCH_BUY_TYPE buyType,
        uint256 _price
    ) public override nonReentrant {
        if (packId == 0) {
            if (buyType == BATCH_BUY_TYPE.BUY_TOTAL) {
                uint256 sum;
                for (uint256 i = 0; i < _idsOnMarket.length; i++) {
                    sum += _buy(_idsOnMarket[i]);
                }
                require(sum <= _price, "Total price is out of range");
            } else {
                for (uint256 i = 0; i < _idsOnMarket.length; i++) {
                    uint256 each = _buy(_idsOnMarket[i]);
                    require(each <= _price, "Total price is out of range");
                }
            }
        } else {
            uint256[] memory newArray = getListingItemInOnePack(packId);
            for (uint256 i = 0; i < newArray.length; i++) {
                _buy(newArray[i]);
            }
        }
    }

    function getIsPackSold(uint256 _pack) public view override returns (bool) {
        return LibMarketplaceStorage.getStorage().packData[_pack].isPackSold;
    }

    function getIdOnMarket(uint256 id)
        public
        view
        override
        returns (LibMarketplaceStorage.MarketItem memory)
    {
        return LibMarketplaceStorage.getStorage().idToMarketItem[id];
    }

    function getPack(uint256 pack)
        public
        view
        override
        returns (LibMarketplaceStorage.PackData memory)
    {
        return LibMarketplaceStorage.getStorage().packData[pack];
    }

    function getListingItemInOnePack(uint256 _pack)
        public
        view
        override
        returns (uint256[] memory)
    {
        // get array length
        LibMarketplaceStorage.PackData memory pack = LibMarketplaceStorage
            .getStorage()
            .packData[_pack];
        uint256 count;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                LibMarketplaceStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .nftContract != address(0)
            ) {
                count++;
            }
        }
        uint256[] memory result = new uint256[](count);
        uint256 countFor2 = 0;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                LibMarketplaceStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .nftContract != address(0)
            ) {
                result[countFor2] = i;
                countFor2++;
            }
        }
        return result;
    }

    /* Buy a marketplace item */
    function _buy(uint256 _idOnMarket) private returns (uint256) {
        uint256 tokenId = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .tokenId;
        uint256 price = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .price;
        address factory = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .nftContract;
        address contractHold = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .contractHold;
        address seller = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .seller;
        bool is_sold = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .sold;

        uint256 packId = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .packId;

        require(is_sold == false, "Buy NFT : Unavailable");
        if (
            contractHold != address(0) &&
            block.timestamp <= OPV_HOLD(contractHold).getTimeToPublic()
        ) {
            require(
                OPV_HOLD(contractHold).checkWinner(msg.sender) == true,
                "Buy NFT : Is now time to buy "
            );
        }

        (
            uint256[] memory saveNumber,
            address[] memory saveAddr
        ) = NativeMarketFeature(address(this)).getBuyData(
                price,
                factory,
                seller,
                tokenId
            );

        for (uint256 i = 0; i < saveAddr.length; i++) {
            if (saveNumber[i] > 0) {
                LibNativeOrdersStorage.getStorage().MainToken.transferFrom(
                    msg.sender,
                    saveAddr[i],
                    saveNumber[i]
                );
            }
        }

        OPVFactory(factory).transferFrom(address(this), msg.sender, tokenId);
        // batchSale  -> save pack have been split
        if (
            packId != 0 &&
            !LibMarketplaceStorage.getStorage().packData[packId].isPackSold
        ) {
            LibMarketplaceStorage
                .getStorage()
                .packData[packId]
                .isPackSold = true;
        }

        emit BuyMarketItem(
            _idOnMarket,
            tokenId,
            factory,
            seller,
            msg.sender,
            price
        );

        delete LibMarketplaceStorage.getStorage().idToMarketItem[_idOnMarket];
        LibMarketplaceStorage.getStorage()._itemsSold++;

        return price;
    }

    function batchCancelSell(uint256 packId, uint256[] memory _idOnMarket)
        public
        override
        nonReentrant
    {
        if (packId == 0) {
            for (uint256 i = 0; i < _idOnMarket.length; i++) {
                _cancelSell(_idOnMarket[i]);
            }
        } else {
            uint256[] memory newArray = getListingItemInOnePack(packId);
            for (uint256 i = 0; i < newArray.length; i++) {
                _cancelSell(newArray[i]);
            }
        }
    }

    function _cancelSell(uint256 _idOnMarket) private {
        bool is_sold = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .sold;
        address seller = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .seller;
        uint256 tokenId = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .tokenId;
        address factory = LibMarketplaceStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .nftContract;

        require(
            msg.sender == seller ||
                msg.sender == LibOwnableStorage.getStorage().owner,
            "Buy NFT : Is not Seller"
        );

        require(is_sold == false, "Buy NFT : Unavailable");

        OPVFactory(factory).transferFrom(address(this), msg.sender, tokenId);
        emit CancelSell(
            _idOnMarket,
            tokenId,
            factory,
            seller,
            LibOwnableStorage.getStorage().owner
        );
        delete LibMarketplaceStorage.getStorage().idToMarketItem[_idOnMarket];
    }

    function cancelSell(uint256 _idOnMarket) public override nonReentrant {
        _cancelSell(_idOnMarket);
    }

    function migrate() external returns (bytes4 success) {
        _registerFeatureFunction(this.batchSale.selector);
        _registerFeatureFunction(this.Sale.selector);
        _registerFeatureFunction(this.getIsPackSold.selector);
        _registerFeatureFunction(this.Buy.selector);
        _registerFeatureFunction(this.batchBuy.selector);
        _registerFeatureFunction(this.cancelSell.selector);
        _registerFeatureFunction(this.getListingItemInOnePack.selector);
        _registerFeatureFunction(this.batchCancelSell.selector);
        _registerFeatureFunction(this.getPack.selector);
        _registerFeatureFunction(this.getIdOnMarket.selector);

        return LibMigrate.MIGRATE_SUCCESS;
    }
}