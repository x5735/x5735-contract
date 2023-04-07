// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IDefaultTracker.sol";

contract HoldersPartition is UUPSUpgradeable, OwnableUpgradeable {
    
    address public rftxAdmin;
    uint256 public claimWait;
    uint256 public lastClaimTime;
    mapping (address => uint256) public lastClaimTimes;

    uint256 public transactionRecordId;
    mapping (uint256 => uint256) public transactionTimeStampMap;
    mapping (uint256 => address) public transactionUserMap;
    mapping (uint256 => uint256) public transactionAmountMap;
    mapping (uint256 => bool) public transactionTypeMap;
    mapping (address => uint256[]) public userTransactions;

    mapping (uint256 => uint256) public tiers;

    uint256 public lastProcessedIndex;
    uint256 public totalBUSD;

    uint256 public minimumBalance;
    uint256 public eligiblePeriod;

    address public REWARD;

    uint256 public gasForProcessing;

    uint256 public availableAmountProcessIndex;
    uint256 public assingTierIndexProcessIndex;

    mapping (uint256 => uint256) public rangeMap;
    mapping (uint256 => uint256) public rangeIndexCountedHoldersMap;

    uint256 maxEligibleBalance;
    uint256 minEligibleBalance;

    bool public distributtionOn;

    address[] public sortedAddressArr;
    uint256[] public withdrawableAmountArr;

    mapping(address => uint256) public withdrawnDividends;

    address public rftxDividendTrackerToken;
    address public divTracker;

    modifier onlyRFXAdmin() {
        require(rftxAdmin == address(msg.sender), "Not a RFX admin!");
        _;
    }

    event Processed(
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	address indexed processor
    );

    event Claim(address indexed account, uint256 amount);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _divTracker,
        address _reward
        ) external initializer {
        __Ownable_init();

        lastClaimTime = block.timestamp;
        tiers[1] = 25;
        tiers[2] = 25;
        tiers[3] = 11;
        tiers[4] = 11;
        tiers[5] = 8;
        tiers[6] = 8;
        tiers[7] = 4;
        tiers[8] = 4;
        tiers[9] = 2;
        tiers[10] = 2;

        claimWait = 3600 * 24 * 7;
        transactionRecordId = 0;

        minimumBalance = 1000000000 * (10**18);
        eligiblePeriod = 3600 * 24 * 7;

        REWARD = _reward;

        gasForProcessing = 300000;
        distributtionOn = false;

        rftxAdmin = _admin;
        divTracker = _divTracker;
        
    }

    function _authorizeUpgrade(address newImplementaion) internal override onlyOwner {}

    receive() external payable {
        // custom function code
        totalBUSD = IERC20(REWARD).balanceOf(address(this));
    }

    function setRematicAdmin(address _address) external onlyOwner {
        require(rftxAdmin != address(_address), "same address is already set");
        rftxAdmin = _address;
    }

    function canAutoClaim(uint256 _lastClaimTime) private view returns (bool) {
    	if(_lastClaimTime > block.timestamp)  {
    		return false;
    	}
    	return block.timestamp - _lastClaimTime >= claimWait;
    }

    function setDivTracker(address _address) external onlyOwner {
        require(divTracker != _address, "already set same value");
        divTracker = _address;
    }

    function process() external onlyRFXAdmin {
        _process();
    }

    function _process() internal {
        if(!distributtionOn){
            return;
        }
        if(block.timestamp > lastClaimTime + claimWait){
            uint256 claims = 0;
            uint256 gasUsed = 0;
            uint256 gasLeft = gasleft();
            uint256 _lastProcessedIndex = lastProcessedIndex;

            while(gasUsed < gasForProcessing && _lastProcessedIndex < sortedAddressArr.length) {

                address account = sortedAddressArr[_lastProcessedIndex];
                if(_processAccount(payable(account), _lastProcessedIndex)) {
                    claims++;
                }
                _lastProcessedIndex ++;

                uint256 newGasLeft = gasleft();
                if(gasLeft > newGasLeft) {
                    gasUsed = gasUsed + (gasLeft - newGasLeft);
                }
                gasLeft = newGasLeft;
            }

            if(_lastProcessedIndex == sortedAddressArr.length) {
                lastClaimTime = block.timestamp;
                lastProcessedIndex = 0;
            }else{
                lastProcessedIndex = _lastProcessedIndex;
            }
            emit Processed(claims, lastProcessedIndex, true, msg.sender);
        }
    }

    function _processAccount(address payable account, uint256 index) internal returns (bool) {
         uint256  _withdrawableDividend = withdrawableAmountArr[index];
        if(_withdrawableDividend > 0){
            bool success = IERC20(REWARD).transfer(account, _withdrawableDividend);
            if(!success) {
                return false;
            }

            withdrawnDividends[account] = withdrawnDividends[account] + _withdrawableDividend;
            
            emit Claim(account, _withdrawableDividend);
            return true;
        }
    	return false;
    }

    function withdrawableDividendOf(address account) external view returns (uint256){
        uint256 tierIndex = _getTierIndexOf(account, sortedAddressArr);
        if(tierIndex > 0){
            uint256 percentage = tiers[tierIndex];
            uint256 defaultWalletCnt = sortedAddressArr.length / 10;
            if(tierIndex == 10){
                if(sortedAddressArr.length > defaultWalletCnt * tierIndex){
                    defaultWalletCnt = sortedAddressArr.length - defaultWalletCnt * tierIndex + defaultWalletCnt;
                }
            }
            uint256 dividend = percentage * totalBUSD / (100 * defaultWalletCnt);
            return dividend;
        }
        return 0;
    }


    function _getTierIndexOf(address account, address[] memory sortedArr) internal pure returns (uint256) {

        bool isRankDeterminded = false;
        uint256 rank = 0;

        while(rank < sortedArr.length && !isRankDeterminded) {
            if(sortedArr[rank] == account){
                isRankDeterminded = true;
            }else{
                rank ++;
            }
        }

        uint256 percentile = rank * 100 / (sortedArr.length - 1);
        uint256 expectedIndex = 1;

        if(percentile >= 90){
            expectedIndex = 1;
        }else if(percentile >= 80){
            expectedIndex = 2;
        }else if(percentile >= 70){
            expectedIndex = 3;
        }else if(percentile >= 60){
            expectedIndex = 4;
        }else if(percentile >= 50){
            expectedIndex = 5;
        }else if(percentile >= 40){
            expectedIndex = 6;
        }else if(percentile >= 30){
            expectedIndex = 7;
        }else if(percentile >= 20){
            expectedIndex = 8;
        }else if(percentile >= 10){
            expectedIndex = 9;
        }else{
            expectedIndex = 10;
        }
        return expectedIndex;
    }



    function _withdrawableDividendOf(uint256 tierIndex, uint256[] memory tierIndexArr) internal view returns (uint256){
        uint256 percentage = tiers[tierIndex];
        uint256 totalCnt = 0;
        for(uint256 i = 0; i < tierIndexArr.length; i ++){
            if(tierIndexArr[i] == tierIndex){
                totalCnt ++;
            }
        }
        return percentage * totalBUSD / (100 * totalCnt);
    }

    function recordTransactionHistory(address payable account, uint256 amount, bool isSell) external onlyRFXAdmin {
        transactionRecordId = transactionRecordId + 1;
        transactionTimeStampMap[transactionRecordId] = block.timestamp;
        transactionUserMap[transactionRecordId] = account;
        transactionAmountMap[transactionRecordId] = amount;
        transactionTypeMap[transactionRecordId] = isSell;
        userTransactions[account].push(transactionRecordId);
    }

    function _getTokenHoldersAvailableAmount (address account) internal view returns (uint256 availableToken) {

        uint256 amount = IERC20(rftxDividendTrackerToken).balanceOf(account);

        availableToken = 0;
        if(amount >= minimumBalance){ //greater than 1B
            if(getSoldTokens(account) == 0){
                uint256 ptoken = _getPurchasedTokens(account);
                if(amount > ptoken){
                    availableToken = amount - ptoken;
                }
            }
        }
    }

    function _getPurchasedTokens(address account) internal view returns(uint256){
        uint256 totalTxCnt = userTransactions[account].length;
        uint256 totalPurchasedTokenAmount = 0;
        if(totalTxCnt > 0){
            for(uint256 i = 0; i < totalTxCnt; i ++){
                uint256 txId = userTransactions[account][i];
                if(!transactionTypeMap[txId]){
                    if(block.timestamp - transactionTimeStampMap[txId] < eligiblePeriod ){
                        totalPurchasedTokenAmount = totalPurchasedTokenAmount + transactionAmountMap[txId];
                    }
                }
            }
        }
        return totalPurchasedTokenAmount;
    }

    function getSoldTokens(address account) internal view returns(uint256){
        uint256 totalTxCnt = userTransactions[account].length;
        uint256 totalSoldTokenAmount = 0;
        if(totalTxCnt > 0){
            for(uint256 i = 0; i < totalTxCnt; i ++){
                uint256 txId = userTransactions[account][i];
                if(transactionTypeMap[txId]){
                    if(block.timestamp - transactionTimeStampMap[txId] < eligiblePeriod ){
                        totalSoldTokenAmount = totalSoldTokenAmount + transactionAmountMap[txId];
                    }
                }
            }
        }
        return totalSoldTokenAmount;
    }

    function widthrawBNB(address _to) external onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    function setClaimWait(uint256 _newvalue) external onlyRFXAdmin {
        require(claimWait != _newvalue, "alredy same value");
        claimWait = _newvalue;
    }

    function setEligiblePeriod(uint256 _newvalue) external onlyRFXAdmin {
        require(eligiblePeriod != _newvalue, "alredy same value");
        eligiblePeriod = _newvalue;
    }

    function setEligibleMinimunBalance(uint256 _newvalue) external onlyRFXAdmin {
        require(minimumBalance != _newvalue, "alredy same value");
        minimumBalance = _newvalue;
    }

    function setTierPercentage(uint256 _tierIndex, uint256 _newvalue) external onlyRFXAdmin {
        require(tiers[_tierIndex] != _newvalue, "alredy same value");
        tiers[_tierIndex] = _newvalue;
    }

    function getTokenHoldersAvailableAmount() public view returns( uint256[] memory, address[] memory ){
        uint256 totalHoldersCnt = IDefaultTracker(divTracker).getNumberOfTokenHolders();
        uint256 _lastProcessedIndex = 0;
        uint256[] memory result1 = new uint256[](totalHoldersCnt);
        address[] memory result2 = new address[](totalHoldersCnt);
        uint256 _iteration = 0;
        while(_lastProcessedIndex < totalHoldersCnt) {
            address key = IDefaultTracker(divTracker).getAccountAtIndex(_lastProcessedIndex);
            uint256 availalbeAmount = _getTokenHoldersAvailableAmount(key);
            if(availalbeAmount > 0){
                result1[_iteration] = availalbeAmount;
                result2[_iteration] = key;
                _iteration ++;
            }
            _lastProcessedIndex ++;
        }

        uint256[] memory newResult1 = new uint256[](_iteration);
        address[] memory newResult2 = new address[](_iteration);
        for(uint256 i = 0; i < _iteration; i++){
            newResult1[i] = result1[i];
            newResult2[i] = result2[i];
        }
        
        return (newResult1, newResult2);
    }


    function quickSort(uint256[] memory arr, address[] memory addressArr,  int left, int right) internal pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint256 pivot = arr[uint256(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint256(i)] < pivot) i++;
            while (pivot < arr[uint256(j)]) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                (addressArr[uint256(i)], addressArr[uint256(j)]) = (addressArr[uint256(j)], addressArr[uint256(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, addressArr, left, j);
        if (i < right)
            quickSort(arr, addressArr, i, right);
    }

    function getDivAmountArr() external view returns( uint256[] memory, address[] memory, uint256[] memory, uint256[] memory) {

        (uint256[] memory tokenHoldersAmountArr, address[] memory tokenHoldersAddressArr)  = getTokenHoldersAvailableAmount();

        quickSort(tokenHoldersAmountArr, tokenHoldersAddressArr, int(0), int(tokenHoldersAmountArr.length - 1));

        uint256[] memory divAmountArr = new uint256[](tokenHoldersAmountArr.length);
        uint256[] memory tierIndexArr = new uint256[](tokenHoldersAmountArr.length);

        uint256 index = 0;
        while(index < tokenHoldersAddressArr.length){
            address account = tokenHoldersAddressArr[index];
            uint256 tierIndex = _getTierIndexOf(account, tokenHoldersAddressArr);
            if(tokenHoldersAmountArr[index] == 0){
                tierIndex = 0;
            }
            tierIndexArr[index] = tierIndex;
            index ++;
        }

        uint256 i = 0;
        while(i < tierIndexArr.length){
            uint256 tierIndex = tierIndexArr[i];
            uint256 div = _withdrawableDividendOf(tierIndex, tierIndexArr);
            divAmountArr[i] = div;
            i ++;
        }

        return (tokenHoldersAmountArr, tokenHoldersAddressArr, tierIndexArr, divAmountArr);
    }

    function setRewardToken(address _reward) external onlyOwner {
        require(REWARD != _reward, "same value already");
        REWARD = _reward;
    }

    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue >= 200000 && newValue <= 500000, "RFX-Holders Parition: gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "RFX-Holders Parition: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function checkIfUnfinishedWork() external view returns(bool){
        if(distributtionOn){
            if(lastProcessedIndex > 0){
                return true;
            }
            return false;
        }
        return false;
    }

    function resetDistributionConfig(bool resetLastCalimWait, uint256 timeGap) external onlyOwner(){
        totalBUSD = IERC20(REWARD).balanceOf(address(this));
        lastProcessedIndex = 0;
        if(resetLastCalimWait){
            lastClaimTime = block.timestamp - timeGap;
        }
    }

    function setDistributtionOn(bool flag) external onlyOwner() {
        require(distributtionOn != flag, "Range Index should be greater than 0");
        distributtionOn = flag;
    }

    function setSortedAddressArr(address[] memory addressArr, uint256[] memory amountArr) external onlyOwner() {
        require(lastProcessedIndex == 0, "Previous Liquidation is not completed yet");
        sortedAddressArr = addressArr;
        withdrawableAmountArr = amountArr;
        _process();
    }

    function updateTotalBUSD() external onlyRFXAdmin {
        totalBUSD = IERC20(REWARD).balanceOf(address(this));
    }

    function updateRFXDividendTrackerToken(address _rftx_div_token) external onlyOwner() {
        require(rftxDividendTrackerToken != _rftx_div_token, "Same value already");
        rftxDividendTrackerToken = _rftx_div_token;
    }
}