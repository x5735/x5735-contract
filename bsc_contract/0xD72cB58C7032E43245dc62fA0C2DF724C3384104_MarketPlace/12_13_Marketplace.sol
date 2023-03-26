// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract MarketPlace is OwnableUpgradeable, ERC721Holder {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    event OrderCreated(uint256[] orderIDList, Order[] orderList);
    event OrderCancelled(uint256[] orderIDList);
    event OrderCompleted(uint256 orderID, Order order);

    struct Order {
        address tokenOwner;
        uint256 tokenID;
        uint256 price;
    }

    Counters.Counter public orderCounter;

    IERC721 public sellingToken;
    IERC20 public currencyToken;
    address public feeAddress;
    uint256 public feePercent;

    mapping(uint256 => Order) public orderIDwithOrderMap;
    mapping(address => bool) public buyerStatusMap;
    mapping(address => bool) public sellerStatusMap;

    function initialize(IERC721 _sellingToken, IERC20 _currencyToken, address _feeAddress, uint8 _feePercent) external initializer {
        __Ownable_init();

        sellingToken = _sellingToken;
        currencyToken = _currencyToken;
        feeAddress = _feeAddress;
        feePercent = _feePercent;
    }

    function setBuyerStatus(address buyer, bool status) external onlyOwner {
        buyerStatusMap[buyer] = status;
    }

    function setSellerStatus(address seller, bool status) external onlyOwner {
        sellerStatusMap[seller] = status;
    }

    function sell(address tokenOwner, uint256[] calldata tokenIDList, uint256 price) external onlySeller {
        require(tokenOwner != address(0), "Marketplace: tokenowner cannot be zero address");

        Order[] memory createdOrder = new Order[](tokenIDList.length);
        uint256[] memory createdOrderIDList = new uint256[](tokenIDList.length);

        for(uint index = 0; index < tokenIDList.length; index++) {
            uint256 tokenID = tokenIDList[index];

            Counters.increment(orderCounter);
            uint256 orderID = Counters.current(orderCounter);

            orderIDwithOrderMap[orderID] = Order({ 
                tokenOwner: tokenOwner, 
                tokenID: tokenID,
                price: price 
            });

            sellingToken.safeTransferFrom(tokenOwner, address(this), tokenID);

            createdOrderIDList[index] = orderID;
            createdOrder[index] = orderIDwithOrderMap[orderID];
        }

        emit OrderCreated(createdOrderIDList, createdOrder);
    }

    function buy(uint256 orderID) external onlyBuyer {
        Order storage order = orderIDwithOrderMap[orderID];
        
        require(order.tokenOwner != address(0), "Marketplace: cannot buy empty order");

        uint256 fee = order.price.mul(feePercent).div(100);
        uint256 excludedFeePrice = order.price.sub(fee);

        currencyToken.transferFrom(msg.sender, order.tokenOwner, excludedFeePrice);
        currencyToken.transferFrom(msg.sender, feeAddress, fee);

        sellingToken.safeTransferFrom(address(this), msg.sender, order.tokenID);

        emit OrderCompleted(orderID, order);

        delete(orderIDwithOrderMap[orderID]);
    }

    function cancelSell(uint256[] calldata orderIDList) external onlySeller {
        for (uint index = 0; index < orderIDList.length; index++) {
            uint256 orderID = orderIDList[index];

            Order storage order = orderIDwithOrderMap[orderID];
        
            require(order.tokenOwner != address(0), "Marketplace: cannot cancel empty order");

            sellingToken.safeTransferFrom(address(this), order.tokenOwner, order.tokenID);

            delete orderIDwithOrderMap[orderID];
        }

        emit OrderCancelled(orderIDList);
    }

    modifier onlySeller() {
        require(sellerStatusMap[msg.sender], "Marketplace: caller is not seller");
        _;
    }

    modifier onlyBuyer() {
        require(buyerStatusMap[msg.sender], "Marketplace: caller is not buyer");
        _;
    }
}