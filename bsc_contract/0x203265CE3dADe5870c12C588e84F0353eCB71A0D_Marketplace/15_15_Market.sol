//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // security against transactions for multiple requests
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter public itemIds;
    Counters.Counter public tokensSold;

    IERC20 public usdt;
    IERC20 public L1bank;

    uint256 public royalties = 10;
    uint256 public minL1bank;
    uint256 public maxGiveAway;

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable author;
        address payable holder;
        uint256 L1bankPrice;
        uint256 usdtPrice;
        bool sold;
    }

    // tokenId return which MarketToken
    mapping(uint256 => MarketItem) private idToMarketItem;

    // listen to events from front end applications
    event MarketItemMinted(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address author,
        address holder,
        uint256 L1bankPrice,
        uint256 usdtPrice,
        bool sold
    );

    event MarketItemPurchased(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address from,
        address to,
        uint256 L1bankPrice,
        uint256 usdtPrice
    );

    constructor(address _usdt, address _L1bank) {
        usdt = IERC20(address(_usdt)); // Testing purpose
        L1bank = IERC20(address(_L1bank)); // Testing purpose

        minL1bank = 100000000000000000;
        maxGiveAway = 999999;
    }

    // @notice function to create a market to put it up for sale
    // @params _nftContract
    function mintMarketItem(
        address _nftContract,
        uint256 _tokenId,
        uint256 _usdtPrice
    ) public nonReentrant {
        require(_usdtPrice > 0, "Price must be more than one");

        itemIds.increment(); // start from 1
        uint256 itemId = itemIds.current();

        //putting it up for sale
        idToMarketItem[itemId] = MarketItem(
            itemId,
            _nftContract,
            _tokenId,
            payable(msg.sender),
            payable(address(0)),
            minL1bank,
            _usdtPrice,
            false
        );

        // NFT transaction
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);

        emit MarketItemMinted(
            itemId,
            _nftContract,
            _tokenId,
            msg.sender,
            address(0),
            minL1bank,
            _usdtPrice,
            false
        );
    }

        // @notice function to create a market to put it up for sale
        // @params _nftContract
        function mintMarketItemByBatch(
            address _nftContract,
            uint256 _startTokenId,
            uint256 _endTokenId,
            uint256 _usdtPrice
        ) public nonReentrant {
            require(_usdtPrice > 0, "Price must be more than one");

             for (uint256 i = _startTokenId; i < _endTokenId; i++) {
                itemIds.increment(); // start from 1
                uint256 itemId = itemIds.current();

                //putting it up for sale
                idToMarketItem[itemId] = MarketItem(
                    itemId,
                    _nftContract,
                    i,
                    payable(msg.sender),
                    payable(address(0)),
                    minL1bank,
                    _usdtPrice,
                    false
                );

                // NFT transaction
                IERC721(_nftContract).transferFrom(msg.sender, address(this), i);

                emit MarketItemMinted(
                    itemId,
                    _nftContract,
                    i,
                    msg.sender,
                    address(0),
                    minL1bank,
                    _usdtPrice,
                    false
                );
             }
        }

    //@notice function to conduct transactions and market sales
    //@params _nftContract Address of nft contract
    //@params  _itemId Id of nft token on marketplace
    function purchaseMarketItemByUsdt(
        address _nftContract,
        uint256 _itemId,
        uint256 _amountOfUsdt
    ) public nonReentrant {
        require(
            IERC721(_nftContract).balanceOf(msg.sender) < maxGiveAway,
            "No more available.!"
        );
        uint256 price = idToMarketItem[_itemId].usdtPrice;
        require(_amountOfUsdt == price, "Not enough USDT");

        uint256 tokenId = idToMarketItem[_itemId].tokenId;
        address preHolder = idToMarketItem[_itemId].holder;

        idToMarketItem[_itemId].holder = payable(msg.sender);
        idToMarketItem[_itemId].sold = true;

        // transfer the amount to the author
        // idToMarketItem[itemId].author.transfer(msg.value);
        if (preHolder != address(0)) {
            uint256 amountToShareAuthor = (((price) * (royalties))) / 100;
            uint256 amountToHolder = price - amountToShareAuthor;
            usdt.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                amountToShareAuthor
            );

            usdt.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                amountToHolder
            );
        } else {
            usdt.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                price
            );
        }

        tokensSold.increment();

        // transfer the token from contract address to the buyer
        IERC721(_nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit MarketItemPurchased(
            _itemId,
            _nftContract,
            tokenId,
            preHolder,
            msg.sender,
            0,
            price
        );
    }

    function purchaseMarketItemByL1bank(
        address _nftContract,
        uint256 _itemId,
        uint256 _amountOfL1bank
    ) public nonReentrant {
        require(
            IERC721(_nftContract).balanceOf(msg.sender) < maxGiveAway,
            "No more available.!"
        );

        require(_amountOfL1bank >= minL1bank, "Not enough L1bank");

        uint256 tokenId = idToMarketItem[_itemId].tokenId;
        address preHolder = idToMarketItem[_itemId].holder;

        idToMarketItem[_itemId].holder = payable(msg.sender);
        idToMarketItem[_itemId].sold = true;

        // transfer the amount to the author
        if (preHolder != address(0)) {
            uint256 amountToShareAuthor = (((_amountOfL1bank) * (royalties))) /
                100;

            uint256 amountToHolder = _amountOfL1bank - amountToShareAuthor;
            L1bank.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                amountToShareAuthor
            );

            L1bank.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                amountToHolder
            );
        } else {
            L1bank.transferFrom(
                msg.sender,
                idToMarketItem[_itemId].author,
                _amountOfL1bank
            );
        }

        tokensSold.increment();

        // transfer the token from contract address to the buyer
        IERC721(_nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit MarketItemPurchased(
            _itemId,
            _nftContract,
            tokenId,
            preHolder,
            msg.sender,
            _amountOfL1bank,
            0
        );
    }

    // @notice function to fetchMarketItems - minting, buying ans selling
    // @return the number of unsold items
    function fetchMarketItemByAddress(address _nftContract)
        external
        view
        returns (MarketItem[] memory)
    {
        uint256 itemCount = itemIds.current();
        uint256 unsoldItemCount = itemIds.current() - tokensSold.current();
        uint256 currentIndex = 0;

        // looping over the number of items created (if number has not been sold populate the array)
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].holder == address(0)) {
                if (idToMarketItem[i + 1].nftContract == _nftContract) {
                    uint256 currentId = i + 1;
                    MarketItem memory currentItem = idToMarketItem[currentId];
                    items[currentIndex] = currentItem;
                    currentIndex += 1;
                }
            }
        }
        return items;
    }

    function fetchMarketItemsWithCursor(uint256 cursor, uint256 howMany)
        external
        view
        returns (MarketItem[] memory, uint256 newCursor)
    {
        uint256 itemCount = itemIds.current();
        uint256 currentIndex = 0;
        uint256 k = 0;

        if (howMany > itemCount - cursor) {
            howMany = itemCount - cursor;
        }

        MarketItem[] memory items = new MarketItem[](howMany);

        for (uint256 i = 1; i <= itemCount; i++) {
            if (idToMarketItem[i].holder == address(0)) {
                if (k >= cursor) {
                    items[currentIndex++] = idToMarketItem[i];
                    if (currentIndex == howMany) break;
                }
                k++;
            }
        }

        return (items, cursor + k);
    }

    function fetchMarketItemsWithCursorMs(
        uint256 cursor,
        uint256 howMany,
        address nftContract
    ) external view returns (MarketItem[] memory, uint256 newCursor) {
        uint256 itemCount = itemIds.current();
        uint256 currentIndex = 0;
        uint256 k = 0;

        if (howMany > itemCount - cursor) {
            howMany = itemCount - cursor;
        }

        MarketItem[] memory items = new MarketItem[](howMany);

        for (uint256 i = 1; i <= itemCount; i++) {
            if (idToMarketItem[i].holder == address(0)) {
                if (idToMarketItem[i].nftContract == nftContract) {
                    if (k >= cursor) {
                        items[currentIndex++] = idToMarketItem[i];
                        if (currentIndex == howMany) break;
                    }
                    k++;
                }
            }
        }

        return (items, cursor + k);
    }

    function fetchMarketItemsWithCursorMr(
        uint256 cursor,
        uint256 howMany,
        address nftContract
    ) external view returns (MarketItem[] memory, uint256 newCursor) {
        uint256 itemCount = itemIds.current();
        uint256 currentIndex = 0;
        uint256 k = 0;
        if (howMany > itemCount - cursor) {
            howMany = itemCount - cursor;
        }
        MarketItem[] memory items = new MarketItem[](howMany);

        for (uint256 i = 1; i <= itemCount; i++) {
            if (idToMarketItem[i].holder == address(0)) {
                if (idToMarketItem[i].nftContract == nftContract) {
                    if (k >= cursor) {
                        items[currentIndex++] = idToMarketItem[i];
                        if (currentIndex == howMany) break;
                    }
                    k++;
                }
            }
        }

        return (items, cursor + k);
    }

    function getMarketItemCount() external view returns (uint256) {
        uint256 marketItemCount = itemIds.current() - tokensSold.current();
        return marketItemCount;
    }

    // return nfts that the user has purchased
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = itemIds.current();
        // a second counter for each individual user
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].holder == msg.sender) {
                itemCount += 1;
            }
        }

        // second loop to loop through the amount you have purchased with itemcount
        // check to see if the holder address is equal to msg.sender
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].holder == msg.sender) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                // current array
                MarketItem memory currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // function for returning an array of minted nfts
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        // instead of .holder it will be the .author
        uint256 totalItemCount = itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].author == msg.sender) {
                itemCount += 1;
            }
        }

        // second loop to loop through the amount you have purchased with itemcount
        // check to see if the holder address is equal to msg.sender
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].author == msg.sender) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem memory currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function setMinL1bank(uint256 _minL1bank) external onlyOwner {
        minL1bank = _minL1bank;
    }

    function setRoyalties(uint256 _royalties) external onlyOwner {
        royalties = _royalties;
    }

    function setMaxGiveAway(uint256 _msxGiveAway) external onlyOwner {
        maxGiveAway = _msxGiveAway;
    }

    function updateL1bankPriceById(uint256 _nftId, uint256 _newPrice)
        external
        onlyHolder(_nftId)
    {
        idToMarketItem[_nftId].L1bankPrice = _newPrice;
    }

    function updateUsdtPriceById(uint256 _nftId, uint256 _newPrice)
        external
        onlyHolder(_nftId)
    {
        idToMarketItem[_nftId].usdtPrice = _newPrice;
    }

    function changeL1bankPriceById(uint256 _nftId, uint256 _newPrice)
        external
        onlyOwner
    {
        idToMarketItem[_nftId].L1bankPrice = _newPrice;
    }

    function changeUsdtPriceById(uint256 _nftId, uint256 _newPrice)
        external
        onlyOwner
    {
        idToMarketItem[_nftId].usdtPrice = _newPrice;
    }

    modifier onlyHolder(uint256 _nftId) {
        require(
            msg.sender == idToMarketItem[_nftId].holder,
            "Authorization denied"
        );
        _;
    }
}