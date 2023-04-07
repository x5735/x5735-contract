// SPDX-License-Identifier: BUSL-1.1

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../base/Controllable.sol";
import "../base/MultiSigWithdrawable.sol";
import "../base/PauseRefundable.sol";
import "../interfaces/IDataLog.sol";

pragma solidity 0.8.15;

contract YaySaleCampaign is PauseRefundable, MultiSigWithdrawable, Controllable, ReentrancyGuard {

    address private constant ZERO_ADDRESS  = address(0);

    struct Stats {
        address currency; // eg: USDT //        
        uint hardCap; // In currency unit
        uint unitPrice;
        uint tokenDpValue;
        uint startTime;
        uint midTime;
        uint endTime;
        uint[6] tierAllocs; // 0: Public, 1-5 Tiers
        bool finished;
    }
    
    Stats public stats;
    
    // Map user address to amount purchased //
    mapping(address => uint) public userPurchaseMap; 
    address[] private _purchaserList;
    uint private _totalSold; // In currency unit
   
    // Whitelist support
    mapping(address => uint) public whitelistTierMap;

    // Refund support
    mapping(address => bool) public userRefundMap; 

    IDataLog private _logger;

    // Events
    event Purchased(address indexed user, uint amount);
    event Refunded(address indexed user, uint amount);
  
    constructor(address currency, uint[3] memory times, uint hardCap, uint unitPrice, uint tokenDp, uint[6] memory tierAllocs, IDataLog logger) {

        require(currency != ZERO_ADDRESS, "Invalid address");
        require(block.timestamp < times[0] && times[0] < times[1] && times[1] < times[2], "Invalid times");
        require(hardCap > 0 && unitPrice > 0 && tokenDp > 0, "Invalid params");
        for (uint n=0; n<6; n++) {
            require(tierAllocs[n] > 0, "Invalid tier alloc");
        }

        stats.currency = currency;
        stats.hardCap = hardCap;
        stats.unitPrice = unitPrice;
        stats.tokenDpValue = 10 ** tokenDp;
        stats.startTime = times[0];
        stats.midTime = times[1];
        stats.endTime = times[2];
        stats.tierAllocs = tierAllocs;

        _logger = logger;
    }


    // A user can only belong to 1 tier. Tier 1-4 (whitelisted) or Tier 0 (public)
    // A user can only buy 1 time with the exact allocation amount. Only the last user can buy the remaining allocation left.
    function buyToken(uint fund) external notPaused nonReentrant {
        
        require(isLive(), "Not live");
        uint bought = userPurchaseMap[msg.sender];
        require(bought == 0, "Already bought");

        (uint tier , uint alloc, uint allocPublic) = getAllocation(msg.sender);
        if (isPrivatePeriod()) {
            require(tier > 0, "Not whitelisted");
        } else {
            alloc = allocPublic; // In public period, even whitelisted users will get public allocation amount.
        }

        // If the remaining amount is less than the allocation, then the user can buy the remaining //
        uint left = getCapLeft();
        alloc = _min(alloc, left);
        
        // Check the fund is the same as alloc
        require(fund == alloc, "Wrong fund amount");

        _totalSold += alloc;
        _transferTokenIn(stats.currency, alloc);
        
        // Record user's Purchase
        userPurchaseMap[msg.sender] = alloc;
        _purchaserList.push(msg.sender);
    
        _log(DataAction.Buy, alloc, 0);
        emit Purchased(msg.sender, alloc);
    }

    // Pause and Refund support
    function setPause(bool set) external onlyOwner {
        require(!stats.finished,"finished");
        _setPause(set);
    }

    function enableRefund() external onlyOwner {
        require(!stats.finished,"finished");
        _setRefundable(true);
    }

    function finishUp() external notPaused onlyController {
        require(!stats.finished,"finished");
        stats.finished = true;
        require(!isLive(), "Still live");

        // Send raised fund to Campaign Owner 
        _transferTokenOut(stats.currency, _totalSold, owner());
    }

    function refund() external canRefund nonReentrant {
        require(!userRefundMap[msg.sender], "Already refunded");
        uint bought = userPurchaseMap[msg.sender];
        require(bought > 0 ,"Did not buy");
        userRefundMap[msg.sender] = true;  

        _transferTokenOut(stats.currency, bought, msg.sender);
         _log(DataAction.Refund, bought, 0);
        emit Refunded(msg.sender, bought);
    }

    function isLive() public view returns(bool) {
        if (block.timestamp < stats.startTime || block.timestamp > stats.endTime) return false;
        return (_totalSold < stats.hardCap); // If reached hardcap, campaign is over.
    }
    
    function isPrivatePeriod() public view returns (bool) {
        return  (block.timestamp >= stats.startTime && block.timestamp <= stats.midTime);
    }

    function getTokenQty(uint fund) external view returns (uint) {
        return ((fund * stats.tokenDpValue) / stats.unitPrice);
    }

    function getTotalSold() external view returns (uint) {
        return _totalSold;
    }

    function getCapLeft() public view returns (uint){
        return stats.hardCap - _totalSold;
    }
    
    function getBuyersCount() external view returns (uint) {
        return _purchaserList.length;
    }
    
    function export(uint index) external view returns (address user, uint bought) {
        user = _purchaserList[index];
        bought = userPurchaseMap[user];
    }
    
    function export(uint startIndex, uint endIndex) external view returns (address[] memory, uint[] memory) {
        
        require(endIndex >= startIndex, "Invalid Range");
        
        uint len = endIndex - startIndex + 1;
        address[] memory users = new address[](len);
        uint[] memory bought = new uint[](len);
        uint index;
        address tempUser;
        for (uint n=startIndex; n<=endIndex; n++) {
            index = n - startIndex;
            tempUser = _purchaserList[n];
            users[index] = tempUser;
            bought[index] = userPurchaseMap[tempUser];
        }
        return (users, bought);
    }
    
    // Whitelisting Support 
    function appendWhitelisted(address[] memory addresses, uint tier) external onlyController {
        require( tier > 0 && tier < 6, "Invalid tier");
        uint len = addresses.length;
        address user;
        for (uint n=0; n<len; n++) {
            user = addresses[n];
            require(whitelistTierMap[user]==0, "Already whitelisted");
            whitelistTierMap[user] = tier;
        }
    }

    function removeWhitelisted(address[] memory addresses) external onlyOwner {
        uint len = addresses.length;
        address user;
        for (uint n=0; n<len; n++) {
            user = addresses[n];
            whitelistTierMap[user] = 0;
        }
    }

    function getAllocation(address user) public view returns(uint tier, uint alloc, uint publicAlloc) {
        tier = whitelistTierMap[user]; // Tier 0 is public
        alloc = stats.tierAllocs[tier];
        publicAlloc = stats.tierAllocs[0];
    }

    // Private Functions    
    function _log(DataAction action, uint data1, uint data2) private {
        _logger.log(address(this), msg.sender, uint(DataSource.Campaign), uint(action), data1, data2);
    }

    function _min(uint a, uint b) private pure returns (uint) {
        return a < b ? a : b;
    }
}