// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract stakingContract {

    event StakeLimitUpdated(Stake);
    event Staking(address userAddress, uint256 level, uint256 amount);
    event Withdraw(address userAddress, uint256 withdrawAmount);

    address public owner;
    IERC20 public token;

    struct UserDetail {
        uint256 level;
        uint256 amount;
        uint256 initialTime;
        uint256 endTime;
        uint256 rewardAmount;
        uint256 withdrawAmount;
        bool status;
    }

    struct Stake {
        uint256 minStakeAmount;
        uint256 rewardPercent;
        uint256 stakeLimit;
    }

    mapping(address =>mapping(uint256 => UserDetail)) internal users;
    mapping(uint256 => Stake) internal stakingDetails;
    mapping(uint256 => bool) internal poolUnstakeStatus;

    modifier onlyOwner() {
        require(owner == msg.sender,"Ownable: Caller is not owner");
        _;
    }

    modifier isEnabled(uint256 level) {
        require(!poolUnstakeStatus[level], "WithdrawStaus: withdraw is not enabled");
        _;
    }

    constructor (IERC20 _token) {
        token = _token;


// Platinum staking 180 days 19.95% apy locked
// Gold staking 120 days 10.99%  locked
// Silver Staking 90 days  6.99
// Bronze Staking 30 days 3.99
        stakingDetails[1] = Stake(100, 399, 30);
        stakingDetails[2] = Stake(150, 699, 90);
        stakingDetails[3] = Stake(30000000000, 1099, 180);
        stakingDetails[4] = Stake(500000000000, 1995, 360);

        owner = msg.sender;  
    }

    function stake(uint256 amount, uint256 level) external returns(bool) {
        require(level > 0 && level <= 4, "Invalid level");
        require(amount >= stakingDetails[level].minStakeAmount, "amount is less than minimumStakeAmount");
        require(!(users[msg.sender][level].status),"user already exist");

        users[msg.sender][level].amount = amount;
        users[msg.sender][level].level = level;
        users[msg.sender][level].endTime = block.timestamp + stakingDetails[level].stakeLimit * 1 days;        
        users[msg.sender][level].initialTime = block.timestamp;
        users[msg.sender][level].status = true;
        token.transferFrom(msg.sender, address(this), amount);
        emit Staking(msg.sender, level, amount);
        return true;
    }


    function getRewards(address account, uint256 level) internal view returns(uint256) {
        if(users[account][level].endTime <= block.timestamp) {
            uint256 stakeAmount = users[account][level].amount;
            uint256 rewardRate = stakingDetails[users[account][level].level].rewardPercent;
            uint256 rewardAmount = stakeAmount * rewardRate / 10000;
            return rewardAmount;
        }
        else {
            return 0;
        }
    }

    function withdraw(uint256 level) external  isEnabled(level) returns(bool) {
        require(level > 0 && level <= 4, "Invalid level");
        require(users[msg.sender][level].status, "user not exist");
        require(users[msg.sender][level].endTime <= block.timestamp, "staking end time is not reached ");
        uint256 rewardAmount = getRewards(msg.sender, level);
        uint256 amount = rewardAmount + users[msg.sender][level].amount;
        token.transfer(msg.sender, amount);

        uint256 rAmount = rewardAmount + users[msg.sender][level].rewardAmount;
        uint256 wAmount = amount + users[msg.sender][level].withdrawAmount;

        users[msg.sender][level] = UserDetail(0, 0, 0, 0, rAmount, wAmount, false);
        emit Withdraw(msg.sender, amount);
        return true;
    }

    function emergencyWithdraw(uint256 level) external returns(uint256) {
        require(level > 0 && level <= 4, "Invalid level");
        require(users[msg.sender][level].status, "user not exist");
        uint256 stakedAmount = users[msg.sender][level].amount; 
        token.transfer(msg.sender, stakedAmount);
        
        uint256 rewardAmount = users[msg.sender][level].rewardAmount;
        uint256 withdrawAmount = users[msg.sender][level].withdrawAmount;
        users[msg.sender][level] = UserDetail(0, 0, 0, 0, rewardAmount, withdrawAmount, false);

        emit Withdraw(msg.sender, stakedAmount);
        return stakedAmount;
    }

    function getUserDetails(address account, uint256 level) external view returns(UserDetail memory, uint256 rewardAmount) {
        uint256 reward = getRewards(account, level);
        return (users[account][level], reward);
    }

    function getStakingPoolDetails(uint256 level) public view returns(Stake memory) {
        return stakingDetails[level];
    }

    function setStakeDetails(uint256 level, Stake memory _stakeDetails) external onlyOwner returns(bool) {
        require(level > 0 && level <= 4, "Invalid level");
        stakingDetails[level] = _stakeDetails;
        emit StakeLimitUpdated(stakingDetails[level]);
        return true;
    }

    function updatePoolStatus(uint256 level, bool status) external onlyOwner {
        poolUnstakeStatus[level] = status;
    }
}