// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/Math.sol";

import "hardhat/console.sol";


interface IMirroredVotingEscrow {
    function balanceOf(address) external view returns(uint);
    function balanceOf(address,uint256) external view returns(uint256);
    function totalSupply() external view returns(uint);
    function voting_escrows(uint) external view returns(address);
    function mirrored_chains_count() external view returns(uint);
    function mirrored_chains(uint index) external view returns(uint chainid, uint ve_count);
    function user_point_epoch(address) external view returns(uint);
    function user_point_epoch(address, uint chainid) external view returns(uint);
    function user_point_epoch(address, uint chainid, uint escrowcount) external view returns(uint);
    function user_point_history__ts(address, uint index, uint chainid, uint escrowcount) external view returns(uint);
    function user_point_history__ts(address, uint index) external view returns(uint);
    function mirrored_user_point_history(address user, uint chain, uint escrow, uint epoch) external view returns(Point memory);
    function user_point_history(address user, uint epoch) external view returns(Point memory);
    struct Point{
        int128 bias;
        int128  slope;
        uint256 ts;
        uint256  blk;
    }
}

interface IERC20Ext {
    function name() external returns(string memory);
    function symbol() external returns(string memory);
}



contract Rewarder is ReentrancyGuard {
    using SafeERC20 for IERC20;


    /* ========== STATE VARIABLES ========== */

    bool public _pause = false;

    struct Reward {
        uint256 periodFinish;
        uint256 rewardsPerEpoch;
        uint256 lastUpdateTime; 
        uint256 totalSupply;
    }

    uint256 public DURATION = 86400;


    mapping(address => uint) public firstBribeTimestamp;
    mapping(address => mapping(uint => Reward)) public rewardData;  // token -> startTimestamp -> Reward
    mapping(address => bool) public isRewardToken;
    address[] public rewardTokens;

    address public ve;
    address public owner;


    // owner -> reward token -> lastTime
    mapping(address => mapping(address => uint256)) public userTimestamp;

    mapping(address => bool) public locked;
    mapping(address => address) public canClaimFor;
    mapping(address => bool) public isCheckpointAddress;

    mapping(address => uint256) public lastBalance;
    mapping(address => uint256) public totalClaimed;
    mapping(address => uint256) public checkPointCounter;
    mapping(address => uint256) public lastUpdate;



    /* ========== CONSTRUCTOR ========== */

    constructor(address _ve)  {      
        ve = _ve;
        owner = msg.sender;
    }

    /* ========== VIEWS ========== */

    function _rewardTokens() external view returns(address[] memory){
        return rewardTokens;
    }

    function rewardsListLength() external view returns(uint256) {
        return rewardTokens.length;
    }

    function totalSupply() external view returns (uint256) {
        return IMirroredVotingEscrow(ve).totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return IMirroredVotingEscrow(ve).balanceOf(_owner);
    }

    function earned(address _owner) public view returns(uint256[] memory){
        uint i = 0;
        uint[] memory reward = new uint[](rewardTokens.length);
        for(i; i < rewardTokens.length; i++){
            address _rewardToken = rewardTokens[i];
            (reward[i], ) = _earned(_owner, _rewardToken);
        }  
        return (reward);   
    }

    function earnedToken(address _owner, address _rewardToken) public view returns(uint256){
        uint reward = 0;
        (reward, ) = _earned(_owner, _rewardToken); 
        return (reward);  
    }

    function _earned(address _owner, address _rewardToken) private view returns(uint256,uint256){
        uint k = 0;
        uint reward = 0;
        uint256 _lastStartTimestamp = lastUpdate[_rewardToken] / DURATION * DURATION;
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];
        uint256 _lastTokenReward = rewardData[_rewardToken][_lastStartTimestamp].periodFinish;

        if(_userLastTime >= _lastTokenReward) {
            return (0, _userLastTime);
        }
        
        // If it's user first claim given a token then _userLastTime is = 0 (< firstBribeTimestamp)
        // Check if the user has some locked amount before firstBribeTimestamp
        // if not then update userLastTime with the olderTimestampAvailable
        // we use blanceOf to find rewards, if user does not have a locked amount he cannot claim the reward on the epoch.
        if(_userLastTime < firstBribeTimestamp[_rewardToken]){

            uint _userOlderTimestamp = userOlderTimestamp(_owner) / DURATION * DURATION;
            
            // if _userOlderTimestamp is 0 then return 0
            if( _userOlderTimestamp == 0){
                return(0,0);
            } else {
                // else if userOlderTimestamp is higher than firstBribeTimestamp then set _userLastTime to _userOlderTimestamp
                if(_userOlderTimestamp > firstBribeTimestamp[_rewardToken]) {
                    _userLastTime = _userOlderTimestamp;
                } else {
                    // else user had xlqdr before bribe started, set userLastTime to firstBribeTimestamp
                    _userLastTime = firstBribeTimestamp[_rewardToken];
                }
            }
        }

        for(k; k < 50; k++){ 
            if(_userLastTime >= _lastTokenReward){
                // if we reach the current epoch, exit
                break;
            }
            reward += _getReward(_owner, _rewardToken, _userLastTime);
            _userLastTime += DURATION;  
                    
        }  
        return (reward, _userLastTime);  
    }


    function _earnedFixed(address _owner, address _rewardToken, uint _times) private view returns(uint256,uint256){
        uint k = 0;
        uint reward = 0;
        uint256 _lastStartTimestamp = lastUpdate[_rewardToken] / DURATION * DURATION;
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];
        uint256 _lastTokenReward = rewardData[_rewardToken][_lastStartTimestamp].periodFinish;

        if(_userLastTime >= _lastTokenReward) {
            return (0, _userLastTime);
        }
        
        // If it's user first claim given a token then _userLastTime is = 0 (< firstBribeTimestamp)
        // Check if the user has some locked amount before firstBribeTimestamp
        // if not then update userLastTime with the olderTimestampAvailable
        // we use blanceOf to find rewards, if user does not have a locked amount he cannot claim the reward on the epoch.
        if(_userLastTime < firstBribeTimestamp[_rewardToken]){

            uint _userOlderTimestamp = userOlderTimestamp(_owner) / DURATION * DURATION;
            
            // if _userOlderTimestamp is 0 then return 0
            if( _userOlderTimestamp == 0){
                return(0,0);
            } else {
                // else if userOlderTimestamp is higher than firstBribeTimestamp then set _userLastTime to _userOlderTimestamp
                if(_userOlderTimestamp > firstBribeTimestamp[_rewardToken]) {
                    _userLastTime = _userOlderTimestamp;
                } else {
                    // else user had xlqdr before bribe started, set userLastTime to firstBribeTimestamp
                    _userLastTime = firstBribeTimestamp[_rewardToken];
                }
            }
        }

        for(k; k < _times; k++){ 
            if(_userLastTime >= _lastTokenReward){
                // if we reach the current epoch, exit
                break;
            }
            reward += _getReward(_owner, _rewardToken, _userLastTime);
            _userLastTime += DURATION;  
                    
        }  
        return (reward, _userLastTime);  
    }

    /// @notice check if user had some balance previous the timestamp
    function userOlderTimestamp(address user) public view returns(uint){
        uint totChains = IMirroredVotingEscrow(ve).mirrored_chains_count();
        uint i = 0;
        uint chainId = 0;
        uint escrow_count = 0;
        uint user_epochs = 0;
        uint olderTimestamp = 0;
        uint tempOlder = 0;
        // check mirrored
        for(i; i < totChains; i++){
            (chainId, escrow_count) = IMirroredVotingEscrow(ve).mirrored_chains(i);
            uint k;
            for(k = 0; k < escrow_count; k++){
                user_epochs = IMirroredVotingEscrow(ve).user_point_epoch(user, chainId, k);
                if(user_epochs > 0){
                    tempOlder = IMirroredVotingEscrow(ve).user_point_history__ts(user, 1, chainId, k);
                    if(tempOlder != 0 && olderTimestamp == 0){
                        olderTimestamp = tempOlder;
                    }
                    if(tempOlder != 0 && tempOlder < olderTimestamp){
                        olderTimestamp = tempOlder;
                    }
                }
            }
        }
        // check native (1 escrow only)
        address _ve = IMirroredVotingEscrow(ve).voting_escrows(0);
        tempOlder = IMirroredVotingEscrow(_ve).user_point_history__ts(user, 1);
        if(tempOlder < olderTimestamp && tempOlder != 0) olderTimestamp = tempOlder;
        if(olderTimestamp == 0 && tempOlder > 0) olderTimestamp = tempOlder;
        
        return olderTimestamp;
    }

    function _getReward(address _owner, address _rewardToken, uint256 _timestamp) internal view returns (uint256) {
        uint256 _balance = _balanceOfAt(_owner, _timestamp);
        if(_balance == 0){
            return 0;
        } else {
            uint256 _rewardPerToken = rewardPerToken(_rewardToken, _timestamp);
            uint256 _rewards = _rewardPerToken * _balance / 1e18;
            return _rewards;
        }
    }

    function _balanceOfAt(address _owner, uint256 _timestamp) internal view returns(uint256) {
        uint totChains = IMirroredVotingEscrow(ve).mirrored_chains_count();
        uint i = 0;
        uint chainId = 0;
        uint escrow_count = 0;
        IMirroredVotingEscrow.Point memory _point;
        uint balanceOfAt = 0;
        uint user_epochs;
        for(i; i < totChains; i++){
            (chainId, escrow_count) = IMirroredVotingEscrow(ve).mirrored_chains(i);
            uint k;
            for(k = 0; k < escrow_count; k++){
                user_epochs = IMirroredVotingEscrow(ve).user_point_epoch(_owner, chainId, k);
                if(user_epochs > 0) {
                    user_epochs = _findNearestMirroredPoint(_owner, chainId, k, user_epochs, _timestamp);
                    _point = IMirroredVotingEscrow(ve).mirrored_user_point_history(_owner, chainId, k, user_epochs);
                    uint dt = _timestamp - _point.ts;
                    balanceOfAt += uint256(uint128(_point.bias)) - dt * uint256(uint128(_point.slope));                    
                }
            }
        }
        
        // check native (1 escrow only)
        address _ve = IMirroredVotingEscrow(ve).voting_escrows(0);
        user_epochs = IMirroredVotingEscrow(_ve).user_point_epoch(_owner);
        if(user_epochs > 0){
            user_epochs = _findNearestPoint(_owner, user_epochs, _timestamp, _ve);
            _point = IMirroredVotingEscrow(_ve).user_point_history(_owner, user_epochs);
            uint dt = _timestamp - _point.ts;
            balanceOfAt += uint256(uint128(_point.bias)) - dt * uint256(uint128(_point.slope)); 
        }     

        return balanceOfAt;              

    }

    function _findNearestMirroredPoint(address _owner, uint chainId, uint escrow, uint max_epochs, uint _timestamp) internal view returns(uint){
        uint i;
        IMirroredVotingEscrow.Point memory _point;
        uint min;
        uint max = max_epochs;
        uint mid = 0;
        for(i=0; i < 128; i++){
            if(min >= max) break;
            mid = (min + max + 2) / 2;
            _point = IMirroredVotingEscrow(ve).mirrored_user_point_history(_owner, chainId, escrow, mid);
            if(_point.ts <= _timestamp) min = mid;
            else max = mid -1;            
        }
        return min;
    }

    function _findNearestPoint(address _owner, uint max_epochs, uint _timestamp, address _ve) internal view returns(uint){
        uint i;
        IMirroredVotingEscrow.Point memory _point;
        uint min;
        uint max = max_epochs;
        uint mid = 0;
        for(i=0; i < 128; i++){
            if(min >= max) break;
            mid = (min + max + 2) / 2;
            _point = IMirroredVotingEscrow(_ve).user_point_history(_owner, mid);
            if(_point.ts <= _timestamp) min = mid;
            else max = mid -1;       
        }
        
        return min;
    }

   

    function rewardPerToken(address _rewardsToken, uint256 _timestmap) public view returns (uint256) {
        uint256 _totalSupply = rewardData[_rewardsToken][_timestmap].totalSupply;
        if (_totalSupply == 0) {
            return 0;
        }
        return rewardData[_rewardsToken][_timestmap].rewardsPerEpoch * 1e18 / _totalSupply;
    }

    /// @dev tokenDecimals
    function simpleRewardDailyAverage(address token) external view returns(uint rewardAverage, uint supplyAverge) {
        uint totsamples = checkPointCounter[token];
        if(totsamples == 0) return (0,0);
        
        rewardAverage = (lastBalance[token]) * 86400 / DURATION;

        supplyAverge = _supplyAverage(token);
    }   

    function _supplyAverage(address token) internal view returns(uint avg){
        // supply does not increase sharply, use last 7 data points
        uint t = _getLastTimestamp(token);
        uint counter = 0;
        uint i = 0;
        uint _totsupp = 0;
        uint ts = 0;
        for(i; i < 7; i++){
            _totsupp = rewardData[token][t - DURATION*i].totalSupply;        
            if(_totsupp > 0){
                counter += 1;
                ts += _totsupp;
            }
        }
        if(counter == 0) return 0;
        return ts / counter;
    }

    function _getLastTimestamp(address token) internal view returns(uint) {
        return lastUpdate[token] / DURATION * DURATION;
    }
 
    /* ========== MUTATIVE FUNCTIONS ========== */

    function claim() external nonReentrant  {
        require(!locked[msg.sender]);
       _claim(msg.sender, msg.sender);
    }

    function claimSingle(address _token, uint _times) external nonReentrant  {
        require(!locked[msg.sender]);
        require(_times > 0);
        require(_times <=150);
        uint256 _userLastTime;
        uint256 reward = 0;
        address _rewardToken = _token;

        (reward, _userLastTime) = _earnedFixed(msg.sender, _rewardToken, _times);          
        if (reward > 0) {
            IERC20(_rewardToken).safeTransfer(msg.sender, reward);
        }
        totalClaimed[_rewardToken] += reward;
        userTimestamp[msg.sender][_rewardToken] = _userLastTime;
    }

    function claimSingleFor(address _token, address user, uint _times) external nonReentrant  {
         require(canClaimFor[user] == msg.sender);
        require(locked[user]);
        require(_times > 0);
        require(_times <=150);
        uint256 _userLastTime;
        uint256 reward = 0;
        address _rewardToken = _token;

        (reward, _userLastTime) = _earnedFixed(user, _rewardToken, _times);          
        if (reward > 0) {
            IERC20(_rewardToken).safeTransfer(msg.sender, reward);
        }
        totalClaimed[_rewardToken] += reward;
        userTimestamp[user][_rewardToken] = _userLastTime;
    }


    function claimTo(address to) external nonReentrant {
        require(!locked[msg.sender]);
       _claim(msg.sender, to);
    }

    function claimFor(address user) external nonReentrant  {
        require(canClaimFor[user] == msg.sender);
        require(locked[user]);
        _claim(user, msg.sender);
    }

    function _claim(address _owner, address _to) internal stop {
        uint256 _userLastTime;
        uint256 reward = 0;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address _rewardToken = rewardTokens[i];

            (reward, _userLastTime) = _earned(_owner, _rewardToken);          
            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_to, reward);
            }
            totalClaimed[_rewardToken] += reward;
            userTimestamp[_owner][_rewardToken] = _userLastTime;
        }
    }




    
    function checkpointAll() external nonReentrant onlyCheckpointAddress {
        uint i = 0;
        for(i; i < rewardTokens.length; i++){
            address _token = rewardTokens[i];
            _checkpoint(_token);
        }
    }

    function checkpointToken(address _token) external nonReentrant onlyCheckpointAddress {
        _checkpoint(_token);
    }

    function _checkpoint(address _token) private {
        if(isRewardToken[_token]){
            uint _startTimestamp = (block.timestamp / DURATION) * DURATION;
            uint lastPeriodFinish = rewardData[_token][_startTimestamp].periodFinish;

            if(block.timestamp >= lastPeriodFinish) {
                if(firstBribeTimestamp[_token] == 0){
                    firstBribeTimestamp[_token] =  _startTimestamp;
                }

                
                //  Rewards are transferred manually from treasury.  
                //  - lastBalance variable is the sum of token amounts transfer in time
                //  - totalClaimed is the the sum of total tokens earned by users
                uint _lastBalance = lastBalance[_token];
                uint db = _lastBalance - totalClaimed[_token];
                uint reward = IERC20(_token).balanceOf(address(this)) - db;

                if(reward > 0){
                    rewardData[_token][_startTimestamp].rewardsPerEpoch = reward;
                    rewardData[_token][_startTimestamp].lastUpdateTime = block.timestamp;
                    rewardData[_token][_startTimestamp].periodFinish = (block.timestamp / DURATION) * DURATION + DURATION;
                    rewardData[_token][_startTimestamp].totalSupply = IMirroredVotingEscrow(ve).totalSupply();

                    lastBalance[_token] += reward;
                    lastUpdate[_token] = block.timestamp;
                    checkPointCounter[_token] += 1;
                }

                emit RewardAdded(_token, reward, _startTimestamp);
            }
        }
    }


    /* ========== RESTRICTED FUNCTIONS ========== */

    function addRewards(address[] memory _rewardsToken) public onlyOwner {
        uint i = 0;
        for(i; i < _rewardsToken.length; i++){
           _addReward(_rewardsToken[i]);
        }
    }

    function addReward(address _rewardsToken) public onlyOwner {
        _addReward(_rewardsToken);
    }
    function _addReward(address _rewardsToken) internal {
        if(!isRewardToken[_rewardsToken]){
            isRewardToken[_rewardsToken] = true;
            rewardTokens.push(_rewardsToken);
        }
    }

    function blockReward(address _rewardToken) public onlyOwner {
        require(isRewardToken[_rewardToken]);
        isRewardToken[_rewardToken] = false;
    }
    function reviveReward(address _rewardToken) public onlyOwner {
        require(!isRewardToken[_rewardToken]);
        isRewardToken[_rewardToken] = true;
    }

    function setLocked(address lockWallet, address receiver, bool status) public onlyOwner {
        locked[lockWallet] = status;
        canClaimFor[lockWallet] = receiver;
    }

    function setCheckpointAddress(address _checkpointAddress, bool status) public onlyOwner {
        isCheckpointAddress[_checkpointAddress] = status;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0));
        owner = _owner;
    }

    function pause() external onlyOwner {
        _pause = true;
    }

    function unpause() external onlyOwner {
        _pause = false;
    }
    

    /* ========== MODIFIERS ========== */

    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }

    
    modifier onlyCheckpointAddress() {
        require(isCheckpointAddress[msg.sender]);
        _;
    }

    modifier stop() {
        require(!_pause);
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(address rewardToken, uint256 reward, uint256 startTimestamp);
    event Recovered(address token, uint256 amount);
}