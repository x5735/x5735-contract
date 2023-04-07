// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/access/Ownable.sol";
import "./DividendPayingTokenInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../IterableMapping.sol";
import "../IterableMapping.sol";
import "hardhat/console.sol";

contract Four01Programe is UUPSUpgradeable, OwnableUpgradeable {

    using IterableMapping for IterableMapping.Map;

    address public defaultTokenTrackerAddress;

    mapping (uint256 => uint256) public indexMinimumContributionMap;
    mapping (uint256 => uint256) public indexCreditPercentageMap;
    uint256 totalNumberOfCredits;

    uint256 public penaltyPercentage;
    mapping (uint256 => uint256) public indexWithdrawTimeMap;
    mapping (uint256 => uint256) public indexWithdrawCreditPercentageMap;
    uint256 totalNumberOfWithrawCredits;
    
    IterableMapping.Map private optInHoldersMap;
    mapping (address => uint256) public four01kAmountMap;
    mapping (address => uint256) public four01kMAmountMap;
    mapping (address => uint256) public contributionTimestampMap;
    mapping (address => uint256) public withdrawMap;
    uint256 public lastPayoutTime;
    
    bool public passivePayoutLaunched;

    mapping (address => bool) public optInMap;
    mapping (address => uint256) public lifeTimeMap;

    modifier onlyDefaultTokenTracker() {
        require(defaultTokenTrackerAddress == address(msg.sender), "Message sender needs to be Default Token Tracker Contract");
        _;
    }

    event WithdrawReady(address indexed account, uint256 four01kAmount, uint256 mAmount, uint256 lifeTime);
    event WithdrawDone(address indexed account, uint256 four01kAmount, uint256 mAmount, uint256 lifeTime);
    event PassivePayout(address indexed account, uint256 payout, uint256 lifeTime);
    event Error(string indexed messageType,  address indexed account, string message);
    event OptedIn(address indexed account,  uint256 percentage, uint256 timestamp);
    event OptedOut(address indexed account,  uint256 lifeTime, uint256 timestamp);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultTokenTracker
    ) external initializer {
        __Ownable_init();

        indexMinimumContributionMap[1] = 5;
        indexMinimumContributionMap[2] = 10;
        indexMinimumContributionMap[3] = 15;

        indexCreditPercentageMap[1] = 1;
        indexCreditPercentageMap[2] = 2;
        indexCreditPercentageMap[3] = 3;

        // uint256 aMonthTime = 30 * 86400;
        // uint256 aYearTime = 365 * 86400;

        penaltyPercentage = 25;

        indexWithdrawTimeMap[1] = 365 * 86400;
        indexWithdrawTimeMap[2] = 2 * 365 * 86400;
        indexWithdrawTimeMap[3] = 3 * 365 * 86400;

        indexWithdrawCreditPercentageMap[1] = 25;
        indexWithdrawCreditPercentageMap[2] = 50;
        indexWithdrawCreditPercentageMap[3] = 100;

        totalNumberOfCredits = 3;
        totalNumberOfWithrawCredits = 3;
        passivePayoutLaunched = false;
        defaultTokenTrackerAddress = _defaultTokenTracker;
        
    }

    function _authorizeUpgrade(address newImplementaion) internal override onlyOwner {}

    receive() external payable {
        // custom function code
        console.log("reveive token from 401 programe", msg.value);
    }
    

    function setDefaultTokenTracker(address _address) external onlyOwner {
        require(defaultTokenTrackerAddress != address(_address), "same address is already set");
        defaultTokenTrackerAddress = _address;
    }

    function startPassivePayoutLaunched() external onlyOwner {
        require(passivePayoutLaunched != false, "PassivePayoutLaunched is already started");
        passivePayoutLaunched = true;
    }

    function pausePassivePayoutLaunched() external onlyOwner {
        require(passivePayoutLaunched != true, "PassivePayoutLaunched is already started");
        passivePayoutLaunched = false;
    }

    function addUser401OptIn(uint256 percentage) external {
        require(percentage <= 100, "invalid value");
        optInHoldersMap.set(msg.sender, percentage);
        contributionTimestampMap[msg.sender] = block.timestamp;
        optInMap[msg.sender] = true;
        emit OptedIn(msg.sender, percentage, block.timestamp);
    }


    function removeUser401OptIn() public {
        require(optInMap[msg.sender] == true, "already optout");
        // optInHoldersMap.remove(msg.sender);
        optInMap[msg.sender] = false;
        lifeTimeMap[msg.sender] = lifeTimeMap[msg.sender] + block.timestamp - contributionTimestampMap[msg.sender];
        emit OptedOut(msg.sender,  lifeTimeMap[msg.sender], block.timestamp);
    }

    function process(address _address, uint256 rewardCount, uint256 _standardAmount) external onlyDefaultTokenTracker {
        uint256 percentage = optInHoldersMap.get(_address);
        uint256 creditPercentage = 0;

        for(uint256 i = 1; i <= totalNumberOfCredits; i++){
            if(percentage >= indexMinimumContributionMap[i]){
                if(indexCreditPercentageMap[i] > 0){
                    creditPercentage = indexCreditPercentageMap[i];
                }
            }
        }
        
        uint256 mCount = _standardAmount * creditPercentage / 100;
        four01kAmountMap[_address] = four01kAmountMap[_address] + rewardCount;
        four01kMAmountMap[_address] = four01kMAmountMap[_address] + mCount;
        // uint256 creditAmount = rewardCount + mCount;
    }

    function getUserPercentageIn401Programe(address _address) public view returns (uint256){
        
        if(optInMap[_address]) {
            uint256 percetage = optInHoldersMap.get(_address);
            if(percetage > 100){
                return 100;
            }
            return percetage;
        }
        return 0;
    }

    function withdraw401KReward(address _account) external view returns(uint256 mAmount, uint256 four01kAmount, uint256 contributionLife ) {
        // withdraw process
        if(optInHoldersMap.get(_account) > 0){ // check if user is optIn
            four01kAmount = four01kAmountMap[_account];
            mAmount = four01kMAmountMap[_account];
            contributionLife = block.timestamp - contributionTimestampMap[_account] + lifeTimeMap[_account];
            if(contributionLife < indexWithdrawTimeMap[1]){
                mAmount = 0;
                four01kAmount = four01kAmount * (100 - 25) / 100;
            }else if(contributionLife < indexWithdrawTimeMap[2]){
                mAmount = indexWithdrawCreditPercentageMap[1] * mAmount / 100;
            }else if(contributionLife < indexWithdrawTimeMap[3]){
                mAmount = indexWithdrawCreditPercentageMap[2] * mAmount / 100;
            }else{
                mAmount = indexWithdrawCreditPercentageMap[3] * mAmount / 100;
            }
        }
    }

    function _withdraw401KReward(address _account) internal view returns(uint256 mAmount, uint256 four01kAmount, uint256 contributionLife ) {
        // withdraw process
        if(optInHoldersMap.get(_account) > 0){ // check if user is optIn
            four01kAmount = four01kAmountMap[_account];
            mAmount = four01kMAmountMap[_account];
            contributionLife = block.timestamp - contributionTimestampMap[_account]  + lifeTimeMap[_account];
            if(contributionLife < indexWithdrawTimeMap[1]){
                mAmount = 0;
                four01kAmount = four01kAmount * (100 - 25) / 100;
            }else if(contributionLife < indexWithdrawTimeMap[2]){
                mAmount = indexWithdrawCreditPercentageMap[1] * mAmount / 100;
            }else if(contributionLife < indexWithdrawTimeMap[3]){
                mAmount = indexWithdrawCreditPercentageMap[2] * mAmount / 100;
            }else{
                mAmount = indexWithdrawCreditPercentageMap[3] * mAmount / 100;
            }
        }
    }

    function resetUserStatus(address _account) external onlyOwner {
        four01kAmountMap[_account] = 0;
        four01kMAmountMap[_account] = 0;
        contributionTimestampMap[_account] = 0;
        lifeTimeMap[_account] = 0;
        optInHoldersMap.remove(_account);
        optInMap[_account] = false;
    }

    function payforLongtermcontributers() external onlyOwner {
        uint256 aMonthTime = 30 * 86400;
        uint256 aYearTime = 365 * 86400;
        if(block.timestamp - lastPayoutTime > aMonthTime){
            for(uint256 i = 0; i < optInHoldersMap.keys.length; i++){
                address account = optInHoldersMap.getKeyAtIndex(i);
                uint256 contributionLife = block.timestamp - contributionTimestampMap[account];
                if(contributionLife > 3 * aYearTime){
                    uint256 four01kAmount = four01kAmountMap[account];
                    uint256 mAmount = four01kMAmountMap[account];
                    uint256 months = contributionLife/aMonthTime;
                    uint256 payouts = (four01kAmount + mAmount) * (11 ** months) / (10 ** months);
                    emit PassivePayout(account, payouts, contributionLife);
                }
            }
            lastPayoutTime = block.timestamp;
        }
    }

    function updateCreditPercentageMap(uint256 index,  uint256 minPercentage, uint256 creditPercentage) external onlyOwner {
        require( index <= totalNumberOfCredits && index > 0, "out of range, 1, 2, 3 ... < totalNumberOfCredits are valid");
        indexCreditPercentageMap[index] = creditPercentage;
        indexMinimumContributionMap[index] = minPercentage;
    }

    function updateWithdrawTimeMap(uint256 index, uint256 _time) external onlyOwner {
        require(index > 0, "out of range, 1, 2, 3");
        require(indexWithdrawTimeMap[index] != _time, "already same value");
        indexWithdrawTimeMap[index] = _time;
    }

    function export401kRewardList() external view returns (
        address[] memory accountArr, 
        uint256[] memory four01kAmountArr, 
        uint256[] memory mAmountArr, 
        uint256[] memory lifeTimeArr, 
        bool[] memory paneltyArr, 
        uint256[] memory totalAmountArr, 
        uint256[] memory optedInPercentageArr
    ){

        accountArr = new address[](optInHoldersMap.keys.length);
        four01kAmountArr = new uint256[](optInHoldersMap.keys.length);
        mAmountArr = new uint256[](optInHoldersMap.keys.length);
        lifeTimeArr = new uint256[](optInHoldersMap.keys.length);
        totalAmountArr = new uint256[](optInHoldersMap.keys.length);
        optedInPercentageArr = new uint256[](optInHoldersMap.keys.length);
        paneltyArr = new bool[](optInHoldersMap.keys.length);

        uint256 index = 0;
        while(index < optInHoldersMap.keys.length){
            address account = optInHoldersMap.keys[index];
            accountArr[index] = account;
            four01kAmountArr[index] = four01kAmountMap[account];
            mAmountArr[index] = four01kMAmountMap[account];
            optedInPercentageArr[index] = optInHoldersMap.get(account);
            (uint256 mAmount, uint256 four01kAmount, uint256 contributionLife) = _withdraw401KReward(account);
            paneltyArr[index] = contributionLife < indexWithdrawTimeMap[1];
            lifeTimeArr[index] = contributionLife;
            totalAmountArr[index] = mAmount + four01kAmount;
            index ++;
        }
    }
}