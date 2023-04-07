// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NativeMarketFeature.sol";
import "../../op-hold.sol";
import "../../op-ref.sol";

import "../storage/LibAuctionStorage.sol";
import "../storage/LibOwnableStorage.sol";

import "./interfaces/IAuctionFeature.sol";

contract AuctionFeature is ReentrancyGuard, IAuctionFeature, FixinCommon {
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

    function saleAuction(
        uint256 _tokenId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid,
        address _contractHold,
        address _factory
    ) public override nonReentrant isFactory(_factory) {
        _saleAuction(
            _tokenId,
            _startTime,
            _endTime,
            _minBid,
            _maxBid,
            _contractHold,
            _factory,
            0
        );
    }

    function _saleAuction(
        uint256 _tokenId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid,
        address _contractHold,
        address _factory,
        uint256 packId
    ) private returns (uint256) {
        LibAuctionStorage.getStorage()._itemIds++;
        uint256 idOnMarket = LibAuctionStorage.getStorage()._itemIds;

        require(
            _startTime < _endTime,
            "starttime have to be less than endtime"
        );
        require(_minBid < _maxBid, "Invalid price");

        LibAuctionStorage.getStorage().idToMarketItem[
            idOnMarket
        ] = LibAuctionStorage.MarketAuctionItem(
            idOnMarket,
            _tokenId,
            _startTime,
            _endTime,
            _minBid,
            _maxBid,
            0,
            address(0),
            _contractHold,
            _factory,
            msg.sender,
            address(0),
            false,
            packId
        );

        OPVFactory(_factory).transferFrom(msg.sender, address(this), _tokenId);

        emit CreateAuction(
            idOnMarket,
            _tokenId,
            _factory,
            msg.sender,
            _startTime,
            _endTime,
            _minBid,
            _maxBid
        );

        return idOnMarket;
    }

    function batchSaleAuction(
        uint256[] memory _tokenIds,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        uint256 _maxBid,
        address _contractHold,
        address _factory
    ) public override isFactory(_factory) nonReentrant {
        LibAuctionStorage.getStorage()._idPacks++;
        uint256 packIndex = LibAuctionStorage.getStorage()._idPacks;
        uint256[] memory storageIdOnMarket = new uint256[](_tokenIds.length);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            storageIdOnMarket[i] = _saleAuction(
                _tokenIds[i],
                _startTime,
                _endTime,
                _minBid,
                _maxBid,
                _contractHold,
                _factory,
                packIndex
            );
        }

        LibAuctionStorage.getStorage().packData[packIndex] = LibAuctionStorage
            .PackData(
                false,
                storageIdOnMarket[0],
                storageIdOnMarket[_tokenIds.length - 1]
            );

        emit NewAuctionPack(packIndex, storageIdOnMarket);
    }

    function getListingItemInOnePackAuction(uint256 _pack)
        public
        view
        override
        returns (uint256[] memory)
    {
        // get array length
        LibAuctionStorage.PackData memory pack = LibAuctionStorage
            .getStorage()
            .packData[_pack];
        uint256 count;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                LibAuctionStorage.getStorage().idToMarketItem[i].nftContract !=
                address(0) &&
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .latestUserBid ==
                address(0)
            ) {
                count++;
            }
        }
        uint256[] memory result = new uint256[](count);
        uint256 countFor2 = 0;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                LibAuctionStorage.getStorage().idToMarketItem[i].nftContract !=
                address(0) &&
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .latestUserBid ==
                address(0)
            ) {
                result[countFor2] = i;
                countFor2++;
            }
        }
        return result;
    }

    function getListingItemInOnePackAuctionForClaim(uint256 _pack)
        private
        view
        returns (uint256[] memory)
    {
        // get array length
        LibAuctionStorage.PackData memory pack = LibAuctionStorage
            .getStorage()
            .packData[_pack];
        uint256 count;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                !LibAuctionStorage.getStorage().idToMarketItem[i].sold &&
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .latestUserBid !=
                address(0)
            ) {
                count++;
            }
        }
        uint256[] memory result = new uint256[](count);
        uint256 countFor2 = 0;
        for (uint256 i = pack.fromId; i <= pack.endId; i++) {
            if (
                !LibAuctionStorage.getStorage().idToMarketItem[i].sold &&
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[i]
                    .latestUserBid !=
                address(0)
            ) {
                result[countFor2] = i;
                countFor2++;
            }
        }
        return result;
    }

    /* Buy a marketplace item */

    function Bid(uint256 _idOnMarket, uint256 _price)
        public
        override
        nonReentrant
    {
        require(
            LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].sold ==
                false,
            "Buy NFT : Unavailable"
        );

        if (
            LibAuctionStorage
                .getStorage()
                .idToMarketItem[_idOnMarket]
                .contractHold !=
            address(0) &&
            block.timestamp <=
            OPV_HOLD(
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .contractHold
            ).getTimeToPublic()
        ) {
            require(
                OPV_HOLD(
                    LibAuctionStorage
                        .getStorage()
                        .idToMarketItem[_idOnMarket]
                        .contractHold
                ).checkWinner(msg.sender) == true,
                "Buy NFT : Is now time to buy "
            );
        }

        require(
            _price >
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .latestBid &&
                _price >=
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .minBid &&
                _price <=
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .maxBid,
            "Your Bid is less than the previous one or not greater than owner expected or greater than maxBid"
        );

        require(
            block.timestamp >=
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .startTime &&
                block.timestamp <=
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .endTime,
            "Out of time to bid"
        );

        uint256 distance = _price -
            LibAuctionStorage
                .getStorage()
                .idToMarketItem[_idOnMarket]
                .latestBid;
        if (
            LibAuctionStorage
                .getStorage()
                .idToMarketItem[_idOnMarket]
                .latestUserBid != address(0)
        ) {
            LibNativeOrdersStorage.getStorage().MainToken.transferFrom(
                msg.sender,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .latestUserBid,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .latestBid
            );

            emit LoseBid(
                _idOnMarket,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .latestUserBid,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .latestBid
            );
        }

        (
            uint256[] memory saveNumber,
            address[] memory saveAddr
        ) = NativeMarketFeature(address(this)).getBuyData(
                distance,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .nftContract,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .seller,
                LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idOnMarket]
                    .tokenId
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

        // update data
        LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .latestBid = _price;
        LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .latestUserBid = msg.sender;

        emit NewBid(
            _idOnMarket,
            LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].tokenId,
            LibAuctionStorage
                .getStorage()
                .idToMarketItem[_idOnMarket]
                .nftContract,
            LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].seller,
            msg.sender,
            _price
        );
        if (
            _price ==
            LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].maxBid
        ) {
            _claimNft(_idOnMarket);
        }
    }

    function _claimNft(uint256 _idOnMarket) private {
        require(
            LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].sold ==
                false,
            "Claim NFT : Already claim"
        );

        uint256 _tokenId = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .tokenId;

        uint256 _latestBid = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .latestBid;
        address _latestUserBid = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .latestUserBid;
        address _seller = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .seller;
        address _factory = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .nftContract;

        if (_latestUserBid == address(0)) {
            OPVFactory(_factory).transferFrom(address(this), _seller, _tokenId);
            emit ClaimNft(
                _idOnMarket,
                _tokenId,
                _factory,
                _seller,
                _seller,
                _latestBid
            );
        } else {
            OPVFactory(_factory).transferFrom(
                address(this),
                _latestUserBid,
                _tokenId
            );
            emit ClaimNft(
                _idOnMarket,
                _tokenId,
                _factory,
                _seller,
                _latestUserBid,
                _latestBid
            );
        }
        LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket].sold = true;
    }

    function claimNft(uint256 _idOnMarket) public override nonReentrant {
        uint256 _endTime = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .endTime;

        require(block.timestamp > _endTime, "Bid not end yet");

        _claimNft(_idOnMarket);
    }

    function batchClaimNft(uint256 pack, uint256[] memory _idsOnMarket)
        public
        override
        nonReentrant
    {
        if (pack == 0) {
            for (uint256 i = 0; i < _idsOnMarket.length; i++) {
                uint256 _endTime = LibAuctionStorage
                    .getStorage()
                    .idToMarketItem[_idsOnMarket[i]]
                    .endTime;

                require(block.timestamp > _endTime, "Bid not end yet");

                _claimNft(_idsOnMarket[i]);
            }
        } else {
            uint256[] memory newArray = getListingItemInOnePackAuctionForClaim(
                pack
            );
            for (uint256 i = 0; i < newArray.length; i++) {
                _claimNft(newArray[i]);
            }
        }
    }

    function batchCancelSellAuction(
        uint256 packId,
        uint256[] memory idsOnMarket
    ) public override nonReentrant {
        if (packId == 0) {
            for (uint256 i = 0; i < idsOnMarket.length; i++) {
                _cancelSellAuction(idsOnMarket[i]);
            }
        } else {
            uint256[] memory newArray = getListingItemInOnePackAuction(packId);
            for (uint256 i = 0; i < newArray.length; i++) {
                _cancelSellAuction(newArray[i]);
            }
        }
    }

    function _cancelSellAuction(uint256 _idOnMarket) private {
        bool _is_sold = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .sold;
        address _seller = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .seller;
        uint256 _tokenId = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .tokenId;
        address _factory = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .nftContract;
        address _latestUserBid = LibAuctionStorage
            .getStorage()
            .idToMarketItem[_idOnMarket]
            .latestUserBid;

        require(
            msg.sender == _seller ||
                msg.sender == LibOwnableStorage.getStorage().owner,
            "Buy NFT : Is not Seller"
        );

        require(_is_sold == false, "Buy NFT : Unavailable");

        require(_latestUserBid == address(0), "there is someone bid your nft");

        OPVFactory(_factory).transferFrom(address(this), msg.sender, _tokenId);
        emit CancelSellAuction(
            _idOnMarket,
            _tokenId,
            _factory,
            _seller,
            LibOwnableStorage.getStorage().owner
        );
        delete LibAuctionStorage.getStorage().idToMarketItem[_idOnMarket];
    }

    function cancelSellAuction(uint256 _idOnMarket)
        public
        override
        nonReentrant
    {
        _cancelSellAuction(_idOnMarket);
    }

    function migrate() external returns (bytes4 success) {
        _registerFeatureFunction(this.saleAuction.selector);
        _registerFeatureFunction(this.batchSaleAuction.selector);
        _registerFeatureFunction(this.getListingItemInOnePackAuction.selector);
        _registerFeatureFunction(this.Bid.selector);
        _registerFeatureFunction(this.claimNft.selector);
        _registerFeatureFunction(this.batchClaimNft.selector);
        _registerFeatureFunction(this.cancelSellAuction.selector);
        _registerFeatureFunction(this.batchCancelSellAuction.selector);

        return LibMigrate.MIGRATE_SUCCESS;
    }
}