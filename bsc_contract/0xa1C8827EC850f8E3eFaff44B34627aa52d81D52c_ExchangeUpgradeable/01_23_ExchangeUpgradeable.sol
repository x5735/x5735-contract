// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../BaseContract.sol";

contract ExchangeUpgradeable is BaseContract {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _exchangeItemIndex;

    struct ExchangeItem {
        address nftContractAddress;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        address paymentToken;
        uint256 amount;
        uint256 amountSold;
    }

    // exchangeItemIndex => ExchangeItem
    mapping(uint256 => ExchangeItem) private _exchangeItem;

    event ExchangeItemCreated(
        uint256 exchangeItemIndex,
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address seller,
        uint256 price,
        address paymentToken
    );
    event ExchangeItemPriceChanged(uint256 exchangeItemIndex, uint256 newPrice);
    event ExchangeItemCanceled(uint256 exchangeItemIndex);
    event ExchangeItemSale(
        uint256 exchangeItemIndex,
        address buyer,
        uint256 price,
        uint256 amount,
        address treasury,
        uint256 feePercent
    );

    function initialize(address multiSigAccount_, address treasury_) public virtual initializer {
        __BaseContract_init(multiSigAccount_, treasury_);
    }

    function createExchangeItem(
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address paymentToken
    ) external {
        bytes memory data = abi.encode(price, paymentToken);
        amount = _transferAsset(contractAddress, _msgSender(), address(this), tokenId, amount, data);
    }

    function _createExchangeItem(
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address paymentToken
    ) internal returns (uint256 exchangeItemIndex) {
        _checkWhitelistPaymentToken(paymentToken);
        require(price > 0, "Error: Invalid price");

        _exchangeItemIndex.increment();
        exchangeItemIndex = _exchangeItemIndex.current();

        _exchangeItem[exchangeItemIndex] = ExchangeItem(
            contractAddress,
            tokenId,
            payable(seller),
            price,
            paymentToken,
            amount,
            0
        );

        emit ExchangeItemCreated(exchangeItemIndex, contractAddress, tokenId, amount, seller, price, paymentToken);
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override nonReentrant whenNotPaused returns (bytes4) {
        _checkWhitelistNFTContract(_msgSender());

        (uint256 price, address paymentToken) = abi.decode(data, (uint256, address));

        _createExchangeItem(from, _msgSender(), tokenId, 1, price, paymentToken);

        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        _checkWhitelistNFTContract(_msgSender());

        (uint256 price, address paymentToken) = abi.decode(data, (uint256, address));

        _createExchangeItem(from, _msgSender(), id, value, price, paymentToken);

        return this.onERC1155Received.selector;
    }

    function updateExchangeItemPrice(uint256 exchangeItemIndex, uint256 newPrice) external nonReentrant whenNotPaused {
        ExchangeItem memory exchangeItem = _exchangeItem[exchangeItemIndex];

        require(_msgSender() == exchangeItem.seller, "Error: Not seller");
        require(exchangeItem.amount > exchangeItem.amountSold, "Error: Sold");

        require(newPrice > 0, "Error: Invalid price");

        _exchangeItem[exchangeItemIndex].price = newPrice;

        emit ExchangeItemPriceChanged(exchangeItemIndex, newPrice);
    }

    function cancelExchangeItem(uint256 exchangeItemIndex) external nonReentrant whenNotPaused {
        ExchangeItem memory exchangeItem = _exchangeItem[exchangeItemIndex];

        require(_msgSender() == exchangeItem.seller, "Error: Not seller");
        require(exchangeItem.amount > exchangeItem.amountSold, "Error: Sold");

        _transferAsset(
            exchangeItem.nftContractAddress,
            address(this),
            exchangeItem.seller,
            exchangeItem.tokenId,
            exchangeItem.amount - exchangeItem.amountSold,
            ""
        );

        delete _exchangeItem[exchangeItemIndex];

        emit ExchangeItemCanceled(exchangeItemIndex);
    }

    function createExchangeSale(uint256 exchangeItemIndex) external payable nonReentrant whenNotPaused {
        ExchangeItem memory exchangeItem = _exchangeItem[exchangeItemIndex];

        require(_msgSender() != exchangeItem.seller);
        require(exchangeItem.seller != address(0), "Error: ExchangeItem not found");
        // require(exchangeItem.amount - exchangeItem.amountSold >= amount, "Error: Amount exceeded");

        uint256 amount = exchangeItem.amount;
        uint256 totalPrice = (exchangeItem.price * amount) / exchangeItem.amount;

        uint256 treasuryReceivable = (totalPrice * feePercent) / (1 ether);
        uint256 sellerReceivable = totalPrice - treasuryReceivable;

        if (exchangeItem.paymentToken != address(0)) {
            require(msg.value == 0, "Error: Payment is ERC20 token");
            require(
                IERC20(exchangeItem.paymentToken).allowance(_msgSender(), address(this)) >= totalPrice,
                "Error: Payment token is not allowed by buyer"
            );

            require(
                IERC20(exchangeItem.paymentToken).transferFrom(_msgSender(), exchangeItem.seller, sellerReceivable),
                "Error: Payment token transfer to seller error"
            );

            if (feePercent != 0) {
                require(
                    IERC20(exchangeItem.paymentToken).transferFrom(_msgSender(), treasury, treasuryReceivable),
                    "Error: Payment token transfer to treasury error"
                );
            }
        } else {
            require(msg.value == totalPrice, "Error: Insufficient balance");

            require(exchangeItem.seller.send(sellerReceivable), "Error: Payment token transfer to seller error");

            if (feePercent != 0) {
                require(treasury.send(treasuryReceivable), "Error: Payment token transfer to treasury error");
            }
        }

        _transferAsset(exchangeItem.nftContractAddress, address(this), _msgSender(), exchangeItem.tokenId, amount, "");

        if (exchangeItem.amountSold + amount == exchangeItem.amount) delete _exchangeItem[exchangeItemIndex];
        else {
            _exchangeItem[exchangeItemIndex].price -= totalPrice;
            _exchangeItem[exchangeItemIndex].amountSold += amount;
        }
        emit ExchangeItemSale(exchangeItemIndex, _msgSender(), totalPrice, amount, treasury, feePercent);
    }

    function getExchangeItem(uint256 exchangeItemIndex) external view returns (ExchangeItem memory) {
        return _exchangeItem[exchangeItemIndex];
    }
}