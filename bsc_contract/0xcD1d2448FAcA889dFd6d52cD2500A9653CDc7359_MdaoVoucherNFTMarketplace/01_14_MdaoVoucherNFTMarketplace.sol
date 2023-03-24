// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./contracts/token/ERC20/IERC20.sol";
import "./contracts/token/ERC721/IERC721.sol";
import "./contracts/token/ERC721/IERC721Receiver.sol";
import "./contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "./contracts/token/ERC20/utils/SafeERC20.sol";
import "./contracts/utils/Address.sol";
import "./contracts/utils/Strings.sol";
import "./contracts/utils/math/Math.sol";
import "./contracts/access/Ownable.sol";
import "./contracts/security/ReentrancyGuard.sol";

interface IMdaoVoucherNFTMarketplace {
    enum PaymentType { Native, Token }

    function listItem(address nftContract, uint256 nftId, uint256 price, PaymentType payType, IERC20 payToken) external;
    function editItem(uint256 itemId, uint256 price, IERC20 payToken) external;
    function removeItem(uint256 itemId) external;
    function buyItem(uint256 itemId) external payable;

    function setNFTCollectionStatus(address nftContract, bool status) external;
    function proposeFee(uint256 fee) external;
    function setFee() external;
    function setFeeAddress(address payable feeAddress) external;

    function marketItemsLength() external view returns (uint256);

    event ListItem(uint256 itemId, address nftContract, uint256 nftId, uint256 price, address seller, PaymentType payType, address payToken);
    event EditItem(uint256 itemId, uint256 price, address payToken, uint256 lockup);
    event RemoveItem(uint256 itemId);
    event BuyItem(uint256 itemId, address buyer);

    event ProposeFee(uint256 fee, uint256 timestamp);
    event SetFee(uint256 fee);
    event SetFeeAddress(address feeAddress);
}

contract MdaoVoucherNFTMarketplace is IMdaoVoucherNFTMarketplace, ReentrancyGuard, Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct MarketItem {
        IERC721 nftContract;
        uint256 nftId;
        uint256 price;
        address payable seller;
        IERC20 payToken;
        uint256 lockup;
        PaymentType payType;
        bool available;
    }

    uint256 constant FEE_DENOMINATOR = 10000;
    uint256 constant FEE_MAX = 2000; // 20%
    uint256 constant EDIT_LOCKUP = 60; // 1 min. lockup
    uint256 constant EDIT_FEE_LOCKUP = 43200; // 12 h. lockup

    mapping(address => bool) nftContracts;

    uint256 public feeProposal;
    uint256 public feeProposalTimestamp;

    uint256 public fee;
    address payable public feeAddress;

    MarketItem[] public marketItems;

    constructor(address payable _feeAddress, uint256 _fee) {
        feeAddress = _feeAddress;
        fee = _fee;
        feeProposal = _fee;
    }

    modifier checkNFT(address _nftContract) {
        require(nftContracts[_nftContract], "Collection isn't supported");
        _;
    }

    modifier checkAvailable(uint256 _itemId) {
        require(marketItems[_itemId].available, "Nft isn't available");
        require(marketItems[_itemId].lockup < block.timestamp, "Nft is locked");
        _;
    }

    modifier checkSeller(uint256 _itemId) {
        require(marketItems[_itemId].seller == msg.sender, "Only nft owner");
        _;
    }

    function listItem(address _nftContract, uint256 _nftId, uint256 _price, PaymentType _payType, IERC20 _payToken) external nonReentrant checkNFT(_nftContract) {
        IERC721(_nftContract).safeTransferFrom(msg.sender, address(this), _nftId);

        marketItems.push(MarketItem(
            IERC721(_nftContract),
            _nftId,
            _price, 
            payable(msg.sender),
            _payToken,
            block.timestamp,
            _payType,
            true
        ));

        emit ListItem(marketItems.length - 1, _nftContract, _nftId, _price, msg.sender, _payType, address(_payToken));
    }

    function editItem(uint256 _itemId, uint256 _price, IERC20 _payToken) external nonReentrant checkAvailable(_itemId) checkSeller(_itemId) {
        marketItems[_itemId].price = _price;
        marketItems[_itemId].payToken = _payToken;
        marketItems[_itemId].lockup = block.timestamp + EDIT_LOCKUP;

        emit EditItem(_itemId, _price, address(_payToken), marketItems[_itemId].lockup);
    }

    function removeItem(uint256 _itemId) external nonReentrant checkAvailable(_itemId) checkSeller(_itemId) {
        marketItems[_itemId].nftContract.safeTransferFrom(address(this), msg.sender, marketItems[_itemId].nftId);
        marketItems[_itemId].available = false;

        emit RemoveItem(_itemId);
    }

    function buyItem(uint256 _itemId) external payable nonReentrant checkAvailable(_itemId) {
        if (marketItems[_itemId].payType == PaymentType.Native) payNative(_itemId);
        else payToken(_itemId);

        marketItems[_itemId].nftContract.safeTransferFrom(address(this), msg.sender, marketItems[_itemId].nftId);
        marketItems[_itemId].available = false;

        emit BuyItem(_itemId, msg.sender);
    }

    function setNFTCollectionStatus(address _nftContract, bool _status) external onlyOwner {
        nftContracts[_nftContract] = _status;
    }

    function proposeFee(uint256 _fee) external onlyOwner {
        require(_fee <= FEE_MAX, "Wrong fee");
        feeProposal = _fee;
        feeProposalTimestamp = block.timestamp;

        emit ProposeFee(feeProposal, feeProposalTimestamp);
    }

    function setFee() external onlyOwner {
        require(feeProposalTimestamp + EDIT_FEE_LOCKUP <= block.timestamp, "Propose is locked");
        fee = feeProposal;

        emit SetFee(fee);
    }

    function setFeeAddress(address payable _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "feeAddress can be address(0)");
        feeAddress = _feeAddress;
        emit SetFeeAddress(feeAddress);
    }

    // INTERNAL FUNCTIONS
    function payNative(uint256 _itemId) internal {
        require(msg.value == marketItems[_itemId].price, "Wrong msg.value");
        uint256 feeAmount = marketItems[_itemId].price * fee / FEE_DENOMINATOR;

        feeAddress.transfer(feeAmount);
        marketItems[_itemId].seller.transfer(msg.value - feeAmount);
    }

    function payToken(uint256 _itemId) internal {
        uint256 feeAmount = marketItems[_itemId].price * fee / FEE_DENOMINATOR;

        marketItems[_itemId].payToken.safeTransferFrom(msg.sender, feeAddress, feeAmount);
        marketItems[_itemId].payToken.safeTransferFrom(msg.sender, marketItems[_itemId].seller, marketItems[_itemId].price - feeAmount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // VIEW FUNCTIONS
    function marketItemsLength() public view returns (uint256) {
        return marketItems.length;
    }
}