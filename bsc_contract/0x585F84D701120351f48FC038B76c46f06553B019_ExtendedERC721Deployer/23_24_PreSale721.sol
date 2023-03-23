pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract PreSale721 is Ownable{

    event NewPreSale(
        uint256 _eventId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _whiteList
    );

    event UpdatedPreSale(
        uint256 _eventId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _whiteList
    );

    event Whitelisted(uint256 eventId, address buyer);
    event SpecialPrice(
        uint256 eventId,
        uint256 tokenId,
        uint256 price
    );
    event TokenReserve(
        address userAddress,
        uint256 tokenId
    );
    event NewPreSalePaymentToken(address);

    struct PreSaleEventInfo {
        uint256 maxTokensPerWallet;
        uint256 startTime;
        uint256 endTime;
        uint256 maxTokensForEvent;
        uint256 tokensSold;
        uint256 price;
        bool whiteList;
    }

    // token ID => user address
    mapping(uint256 => address) public reservedToken;
    // eventId => tokenId => token price
    mapping(uint256 => mapping(uint256 => uint256)) public specialPrice;
    // eventId => user address => quantity
    mapping(uint256 => mapping(address => uint256)) private tokensBoughtDuringEvent;
    // eventId => token ID => user address => quantity
    mapping (uint256 => mapping(uint256 => mapping(address => uint256))) private tokensOfSameIdBoughtDuringEvent;
    // user address => eventId => whitelisted
    mapping(address => mapping(uint256 => bool)) public isAddressWhitelisted;
    // eventId => PreSaleEventInfo
    // Contains all Event information. Should be called on Front End to receive up-to-date information
    PreSaleEventInfo[] public preSaleEventInfo;
    //address(0) for ETH, anything else - for ERC20
    address public preSalePaymentToken;

    /*
     * Params
     * address buyer - Buyer address
     * uint256 tokenId - ID index of tokens, user wants to buy
     * uint256 eventId - Event ID index
     *
     * Function returns price of tokens for specific buyer, event ID
     * and decides if user can buy these tokens
     * {availableForBuyer} return param decides if buyer can purchase right now
     * This function should be called on Front End before any pre purchase transaction
     */
    function getTokenInfo
    (
        address buyer,
        uint256 tokenId,
        uint256 eventId
    )
        external
        view
        returns (uint256 tokenPrice, address paymentToken, bool availableForBuyer)
    {
        uint256 tokenPrice = preSaleEventInfo[eventId].price;
        bool availableForBuyer = true;

        //Special price check
        if(specialPrice[eventId][tokenId] != 0){
            tokenPrice = specialPrice[eventId][tokenId];
        }

        if((    //Whitelist check
            preSaleEventInfo[eventId].whiteList
            && isAddressWhitelisted[buyer][eventId] == false
            )||( //Reserve check
            reservedToken[tokenId] != address(0)
            && reservedToken[tokenId] != buyer
            )||( //Time check
            block.timestamp < preSaleEventInfo[eventId].startTime
            || block.timestamp > preSaleEventInfo[eventId].endTime
            )||( //Maximum tokens for event check
            preSaleEventInfo[eventId].maxTokensForEvent != 0 &&
            (preSaleEventInfo[eventId].tokensSold + 1) > preSaleEventInfo[eventId].maxTokensForEvent
            )||( //Maximum tokens per wallet
            preSaleEventInfo[eventId].maxTokensPerWallet != 0
            && tokensBoughtDuringEvent[eventId][buyer] + 1 > preSaleEventInfo[eventId].maxTokensPerWallet
        ))
        {
            availableForBuyer = false;
        }

        return (tokenPrice, preSalePaymentToken, availableForBuyer);
    }

    /*
     * Params
     * uint256 _maxTokensPerWallet - How many tokens in total a wallet can buy?
     * uint256 _startTime - When does the sale for this event start?
     * uint256 _startTime - When does the sale for this event end?
     * uint256 _maxTokensForEvent - What is the total amount of tokens sold in this Event?
     * uint256 _price - What is the price per one token?
     * bool _whiteList - Will event allow to participate only whitelisted addresses?
     *
     * Adds new presale event to the list (array)
     */
    function createPreSaleEvent(
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForEvent,
        uint256 _price,
        bool _whiteList
    )
        external
        onlyOwner
    {
        require(_startTime < _endTime, 'Wrong timeline');

        preSaleEventInfo.push(
            PreSaleEventInfo({
                maxTokensPerWallet: _maxTokensPerWallet,
                startTime: _startTime,
                endTime: _endTime,
                maxTokensForEvent: _maxTokensForEvent,
                tokensSold: 0,
                price: _price,
                whiteList: _whiteList
            })
        );

        emit NewPreSale(
            (preSaleEventInfo.length - 1),
            _maxTokensPerWallet,
            _startTime,
            _endTime,
            _maxTokensForEvent,
            _price,
            _whiteList
        );
    }


    /*
     * Params
     * uint256 _eventId - ID index of event
     * uint256 _maxTokensPerWallet - How many tokens in total a wallet can buy?
     * uint256 _startTime - When does the sale for this event start?
     * uint256 _startTime - When does the sale for this event end?
     * uint256 _maxTokensForEvent - What is the total amount of tokens sold in this Event?
     * uint256 _price - What is the price per one token?
     * bool _whiteList - Will event allow to participate only whitelisted addresses?
     *
     * Updates presale event in the list (array)
     */
    function updatePreSaleEvent(
        uint256 _eventId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForEvent,
        uint256 _price,
        bool _whiteList
    )
        external
        onlyOwner
    {
        require(_startTime < _endTime, 'Wrong timeline');
        require(preSaleEventInfo[_eventId].startTime > block.timestamp, 'Event is already in progress');

        preSaleEventInfo[_eventId].maxTokensPerWallet = _maxTokensPerWallet;
        preSaleEventInfo[_eventId].startTime = _startTime;
        preSaleEventInfo[_eventId].endTime = _endTime;
        preSaleEventInfo[_eventId].maxTokensForEvent = _maxTokensForEvent;
        preSaleEventInfo[_eventId].price = _price;
        preSaleEventInfo[_eventId].whiteList = _whiteList;

        emit UpdatedPreSale(
            _eventId,
            _maxTokensPerWallet,
            _startTime,
            _endTime,
            _maxTokensForEvent,
            _price,
            _whiteList
        );
    }


    /*
     * Params
     * uint256 eventId - Event ID index
     * address buyer - User that should be whitelisted
     *
     * Function add user to whitelist of private event
     */
    function addToWhitelist(
        uint256 eventId,
        address buyer
    ) external onlyOwner {
        require(preSaleEventInfo[eventId].whiteList, 'Event is not private');
        isAddressWhitelisted[buyer][eventId] = true;

        emit Whitelisted(eventId, buyer);
    }


    /*
     * Params
     * uint256 eventId - Event ID index
     * uint256 tokenId - Index ID of token, that should have special price
     * uint256 price - Price for this token ID during this event
     *
     * Function sets special price for a token of specific ID for a specific event
     */
    function setSpecialPriceForToken(
        uint256 eventId,
        uint256 tokenId,
        uint256 price
    ) external onlyOwner{
        specialPrice[eventId][tokenId] = price;

        emit SpecialPrice(eventId, tokenId, price);
    }


    /*
     * Params
     * address userAddress - Address of user, who should exclusively buy this token
     * uint256 tokenId - Token index ID
     *
     * Function reserves specific token for specific user on the time of any pre sale event
     * Set address(0) to unreserve
     */
    function reserveToken(
        address userAddress,
        uint256 tokenId
    ) external onlyOwner{
        reservedToken[tokenId] = userAddress;

        emit TokenReserve(userAddress, tokenId);
    }


    /*
     * Params
     * uint256 eventId - Event ID index
     * address buyer - User address, who bought the tokens
     *
     * Function counts tokens bought for different counters
     */
    function _countTokensBought(
        uint256 eventId,
        address buyer
    ) internal {
        if(preSaleEventInfo[eventId].maxTokensPerWallet != 0){
            tokensBoughtDuringEvent[eventId][buyer] += 1;
        }
        preSaleEventInfo[eventId].tokensSold += 1;
    }


    /*
     * Params
     * address _preSalePaymentToken - ERC20 address for payment token/ 0 address for ETH
     *
     * Function sets payment token address for pre sale transactions
     */
    function setPreSalePaymentToken (address _preSalePaymentToken) external onlyOwner{
        preSalePaymentToken = _preSalePaymentToken;

        emit NewPreSalePaymentToken(_preSalePaymentToken);
    }
}