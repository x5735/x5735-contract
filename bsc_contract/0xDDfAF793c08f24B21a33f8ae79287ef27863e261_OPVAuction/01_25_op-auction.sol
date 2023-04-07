// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./op-factory.sol";
import "./op-hold.sol";
import "./op-ref.sol";

contract OPVAuction is ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    bool public initilized;

    address owner;
    address feeAddress;

    IERC20 public MainToken;
    ERC721 public Factory;
    OPV_REF public RefContract;

    uint256 feeCreator;
    uint256 feeMarket;
    uint256 feeRef;

    mapping(uint256 => MarketAuctionItem) private idToMarketItem;
    mapping(address => bool) public AllFactoryBasic;
    mapping(address => bool) public AllFactoryVip;
    mapping(address => bool) public blackListFee;

    function initialize(
        address _MainToken,
        address _RefAddress,
        address _FeeAddress
    ) public {
        require(!initilized, "Initilized!");
        owner = msg.sender;
        RefContract = OPV_REF(_RefAddress);
        MainToken = IERC20(_MainToken);
        feeAddress = _FeeAddress;
        initilized = true;

        MainToken.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    struct MarketAuctionItem {
        uint256 idOnMarket;
        uint256[] tokenIds;
        uint256 startTime;
        uint256 endTime;
        uint256 minBid;
        uint256 latestBid;
        address latestUserBid;
        address contractHold;
        address[] nftContracts;
        address seller;
        address owner;
        bool sold;
    }

    event CreateAuction(
        uint256 indexed idOnMarket,
        uint256[] tokenIds,
        address[] nftContracts,
        address seller,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid
    );

    event NewBid(
        uint256 indexed idOnMarket,
        uint256[] tokenIds,
        address[] nftContracts,
        address seller,
        address bidder,
        uint256 price
    );

    event ClaimNft(
        uint256 indexed idOnMarket,
        uint256[] tokenIds,
        address[] nftContracts,
        address seller,
        address buyer,
        uint256 price
    );

    event CancelSell(
        uint256 indexed idOnMarket,
        uint256[] tokenIds,
        address[] nftContracts,
        address seller,
        address owner
    );

    event LoseBid(uint256 indexed idOnMarket, address user, uint256 returnBid);

    modifier onlyOwner(address sender) {
        require(sender == owner, "Is not Owner");
        _;
    }

    modifier isFactory(address _factory) {
        require(
            AllFactoryBasic[_factory] == true ||
                AllFactoryVip[_factory] == true,
            "Is Not Factory"
        );
        _;
    }

    /**
     * @dev Allow factory.
     */
    function addFactoryBasic(address proxy) public onlyOwner(msg.sender) {
        require(AllFactoryBasic[proxy] == false, "Invalid proxy address");

        AllFactoryBasic[proxy] = true;
    }

    /**
     * @dev Remove operation from factory list.
     */
    function removeFactoryBasic(address proxy) public onlyOwner(msg.sender) {
        AllFactoryBasic[proxy] = false;
    }

    /**
     * @dev Allow factory.
     */
    function addFactoryVip(address proxy) public onlyOwner(msg.sender) {
        require(AllFactoryVip[proxy] == false, "Invalid proxy address");

        AllFactoryVip[proxy] = true;
    }

    /**
     * @dev Remove operation from factory list.
     */
    function removeFactoryVip(address proxy) public onlyOwner(msg.sender) {
        AllFactoryVip[proxy] = false;
    }

    function saleAuction(
        uint256[] calldata _tokenIds,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid,
        address _contractHold,
        address[] calldata _factories
    ) public nonReentrant {
        _itemIds.increment();
        uint256 idOnMarket = _itemIds.current();

        require(
            _startTime < _endTime,
            "starttime have to be less than endtime"
        );

        require(
            _tokenIds.length == _factories.length,
            "tokenIds length must same as factories length"
        );

        idToMarketItem[idOnMarket] = MarketAuctionItem(
            idOnMarket,
            _tokenIds,
            _startTime,
            _endTime,
            _minBid,
            0,
            address(0),
            _contractHold,
            _factories,
            msg.sender,
            address(0),
            false
        );

        for (uint256 i = 0; i < _factories.length; i++) {
            OPVFactory(_factories[i]).transferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
        }

        emit CreateAuction(
            idOnMarket,
            _tokenIds,
            _factories,
            msg.sender,
            _startTime,
            _endTime,
            _minBid
        );
    }

    function getBuyData(
        uint256 price_,
        address factory_,
        address seller_,
        uint256 tokenId_
    ) public view returns (uint256[] memory, address[] memory) {
        uint256[] memory saveNumber = new uint256[](4);
        address[] memory saveAddr = new address[](4);
        saveNumber[0] = (price_ / 10000) * feeRef;
        saveNumber[1] = (price_ / 10000) * feeMarket;
        saveNumber[2] = (price_ / 10000) * feeCreator;
        // uint256 feeCreatorItem = (price / 10000) * feeCreator;
        // uint256 feeMarketItem = (price / 10000) * feeMarket;
        // uint256 feeRefItem = (price / 10000) * feeRef;

        if (AllFactoryVip[factory_] == true) {
            if (blackListFee[seller_] == true) {
                if (
                    RefContract.getRef(seller_) != address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                } else if (
                    RefContract.getRef(seller_) != address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) == address(0)
                ) {
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = feeAddress;
                } else if (
                    RefContract.getRef(seller_) == address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    //Have creator
                    //Money to ref
                    // MainToken.transferFrom(msg.sender, feeAddress, feeRefItem);
                    saveAddr[0] = feeAddress;
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                    // Money to fund creator
                }
            } else {
                if (
                    RefContract.getRef(seller_) != address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    // Have ref & creator
                    //Money to ref
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = feeAddress;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                } else if (
                    RefContract.getRef(seller_) != address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) == address(0)
                ) {
                    //Have ref
                    //Money to ref
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = feeAddress;
                    saveAddr[2] = feeAddress;
                } else if (
                    RefContract.getRef(seller_) == address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    // Have creator
                    // Money to fund creator
                    saveAddr[0] = feeAddress;
                    saveAddr[1] = feeAddress;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                }
            }
        } else {
            if (blackListFee[seller_] == true) {
                if (RefContract.getRef(seller_) != address(0)) {
                    //Money to ref
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = feeAddress;
                } else {
                    // Money to fund creator + ref
                    saveAddr[0] = feeAddress;
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = feeAddress;
                }
            } else {
                if (RefContract.getRef(seller_) != address(0)) {
                    //Money to ref
                    saveAddr[0] = RefContract.getRef(seller_);
                    saveAddr[1] = feeAddress;
                    saveAddr[2] = feeAddress;
                } else {
                    // Money to fund creator + ref + market
                    saveAddr[0] = feeAddress;
                    saveAddr[1] = feeAddress;
                    saveAddr[2] = feeAddress;
                }
            }
        }

        saveAddr[3] = seller_;
        saveNumber[3] = price_ - saveNumber[0] - saveNumber[1] - saveNumber[2];
        return (saveNumber, saveAddr);
    }

    /* Buy a marketplace item */

    //avoid stack over too deep
    uint256[] tokenIds;
    uint256 minBid;
    uint256 latestBid;
    uint256 startTime;
    uint256 endTime;
    address[] factories;
    address contractHold;
    address seller;
    address latestUserBid;
    bool is_sold;

    function Bid(uint256 _idOnMarket, uint256 _price) public nonReentrant {
        tokenIds = idToMarketItem[_idOnMarket].tokenIds;
        minBid = idToMarketItem[_idOnMarket].minBid;
        latestBid = idToMarketItem[_idOnMarket].latestBid;
        startTime = idToMarketItem[_idOnMarket].startTime;
        endTime = idToMarketItem[_idOnMarket].endTime;
        factories = idToMarketItem[_idOnMarket].nftContracts;
        contractHold = idToMarketItem[_idOnMarket].contractHold;
        seller = idToMarketItem[_idOnMarket].seller;
        latestUserBid = idToMarketItem[_idOnMarket].latestUserBid;
        is_sold = idToMarketItem[_idOnMarket].sold;

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

        require(
            _price > latestBid && _price >= minBid,
            "Your Bid is less than the previous one or not greater than owner expected"
        );

        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Out of time to bid"
        );

        uint256 distance = _price - latestBid;
        if (latestUserBid != address(0)) {
            MainToken.transferFrom(msg.sender, latestUserBid, latestBid);

            emit LoseBid(_idOnMarket, latestUserBid, latestBid);
        }

        for (uint256 j = 0; j < factories.length; j++) {
            (
                uint256[] memory saveNumber,
                address[] memory saveAddr
            ) = getBuyData(
                    distance.div(factories.length),
                    factories[j],
                    seller,
                    tokenIds[j]
                );
            for (uint256 i = 0; i < saveAddr.length; i++) {
                if (saveNumber[i] > 0) {
                    MainToken.transferFrom(
                        msg.sender,
                        saveAddr[i],
                        saveNumber[i]
                    );
                }
            }
        }

        // update data
        idToMarketItem[_idOnMarket].latestBid = _price;
        idToMarketItem[_idOnMarket].latestUserBid = msg.sender;

        emit NewBid(
            _idOnMarket,
            tokenIds,
            factories,
            seller,
            msg.sender,
            _price
        );
    }

    function claimNft(uint256 _idOnMarket) public nonReentrant {
        tokenIds = idToMarketItem[_idOnMarket].tokenIds;
        endTime = idToMarketItem[_idOnMarket].endTime;
        latestBid = idToMarketItem[_idOnMarket].latestBid;
        latestUserBid = idToMarketItem[_idOnMarket].latestUserBid;
        seller = idToMarketItem[_idOnMarket].seller;
        factories = idToMarketItem[_idOnMarket].nftContracts;

        require(block.timestamp > endTime, "Bid not end yet");
        address nftReceiver = latestUserBid == address(0)
            ? seller
            : latestUserBid;
        for (uint256 i = 0; i < factories.length; i++) {
            OPVFactory(factories[i]).transferFrom(
                address(this),
                nftReceiver,
                tokenIds[i]
            );
        }
        emit ClaimNft(
            _idOnMarket,
            tokenIds,
            factories,
            seller,
            nftReceiver,
            latestBid
        );
    }

    function cancelSell(uint256 _idOnMarket) public nonReentrant {
        is_sold = idToMarketItem[_idOnMarket].sold;
        seller = idToMarketItem[_idOnMarket].seller;
        tokenIds = idToMarketItem[_idOnMarket].tokenIds;
        factories = idToMarketItem[_idOnMarket].nftContracts;
        latestUserBid = idToMarketItem[_idOnMarket].latestUserBid;
        require(
            msg.sender == seller || msg.sender == owner,
            "Buy NFT : Is not Seller"
        );
        require(is_sold == false, "Buy NFT : Unavailable");
        require(latestUserBid == address(0), "there is someone bid your nft");
        for (uint256 i = 0; i < factories.length; i++) {
            OPVFactory(factories[i]).transferFrom(
                address(this),
                msg.sender,
                tokenIds[i]
            );
        }
        emit CancelSell(_idOnMarket, tokenIds, factories, seller, owner);
        delete idToMarketItem[_idOnMarket];
    }

    function getFeeMarket() public view returns (uint256) {
        return feeMarket;
    }

    function setFeeMarket(uint256 percent) public onlyOwner(msg.sender) {
        feeMarket = percent;
    }

    function getFeeCreator() public view returns (uint256) {
        return feeCreator;
    }

    function setFeeCreator(uint256 percent) public onlyOwner(msg.sender) {
        feeCreator = percent;
    }

    function getFeeRef() public view returns (uint256) {
        return feeRef;
    }

    function setFeeRef(uint256 percent) public onlyOwner(msg.sender) {
        feeRef = percent;
    }

    function getFeeAddress() public view returns (address) {
        return feeAddress;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner(msg.sender) {
        feeAddress = _feeAddress;
    }

    function getRefAddress() public view returns (address) {
        return address(RefContract);
    }

    function setRefAddress(address _RefAddress) public onlyOwner(msg.sender) {
        RefContract = OPV_REF(_RefAddress);
    }

    function setMainTokenAddress(
        address _MainToken
    ) public onlyOwner(msg.sender) {
        MainToken = IERC20(_MainToken);
    }

    function setBlackListFee(
        address[] memory user
    ) public onlyOwner(msg.sender) {
        for (uint256 index = 0; index < user.length; index++) {
            blackListFee[user[index]] = true;
        }
    }

    function removeBlackListFee(
        address[] memory user
    ) public onlyOwner(msg.sender) {
        for (uint256 index = 0; index < user.length; index++) {
            blackListFee[user[index]] = false;
        }
    }
}