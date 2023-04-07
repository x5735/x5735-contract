//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "../access/Controller.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error notEnoughBalance();
error alreadyExist();
error doesntExist();
error aprTooLow();
error exceedMaxStakeable();
error stakeTooLow();
error invalidStartTime();
error existingStakeName();
error stakingClosed();
error tooEarly();
error hasntStarted();
error notFeeAddress();
error noStaked();
error noRewards();
error noStakeOrRewards();
error graceNotFinished();
error alreadyUnlocked();
error invalidMinAllocation();
error poolFilled();

struct StakingProfile{
    address stakingToken;
    address rewardToken;
    uint256 startTime;
    uint256 duration;
    uint256 rewardRate;
    uint256 rewardAllocated;
    uint256 rewardsLeft;
    uint256[2] allocations; // 0 is min allocation // 1 is max allocation
    uint256 TotalStaked;
    uint256 currentlyStaked;
    uint256 unstakeFees;
    bool active;
    uint256 gracePeriod;
}
struct stakeInfo{
    uint256 amountStaked;
    uint256 stakedFromTS;
    uint256 rewards;
    uint256 graceStartedFromTS;
}
contract NeoLockedStaking is Controller,ReentrancyGuard{
    using SafeERC20 for IERC20;
    mapping(string => StakingProfile) public AllStakingProfiles;
    mapping(address => mapping(string=>mapping(string=>stakeInfo))) public stakes;
    address public feeAddress;
    mapping(address => mapping(string=> uint256)) public maxStakedInPool;
    event stakingProfileCreated(string indexed profileID);
    event closedStaking(string indexed profileID);
    event staked(address indexed staker,string indexed profileID,string stakeName);
    event unstaked(address indexed staker,string indexed profileID,string stakeName);
    event claimed(address indexed staker,string indexed profileID,string stakeName);
    event graceStarted(address indexed staker,string indexed profileID,string stakeName);

    function stake(
        uint256 amount,
        string memory staking_id,
        string memory stakeName) 
    external isExist(staking_id) nonReentrant{  
        StakingProfile memory p = AllStakingProfiles[staking_id];
        uint256 maxStakeable = getMaxStakeable(staking_id);
        uint256 minStakable = getMinStakeable(staking_id);
        if(block.timestamp < p.startTime){
            revert hasntStarted();
        }
        if(amount > maxStakeable){
            revert exceedMaxStakeable();
        }
        if(amount < minStakable){
            revert stakeTooLow();
        }
        stakeInfo memory s = stakes[msg.sender][staking_id][stakeName];
        if(s.stakedFromTS != 0){
            revert existingStakeName();
        }
        IERC20(p.stakingToken).safeTransferFrom(msg.sender,address(this),amount);
        uint256 reward = amount * p.rewardRate * p.duration / 1e18;
        s = stakeInfo(
            amount,
            block.timestamp,
            reward,
            0
        );
        p.rewardsLeft -= reward;
        p.TotalStaked += amount;
        p.currentlyStaked += amount;
        stakes[msg.sender][staking_id][stakeName] = s;
        AllStakingProfiles[staking_id] = p; 
        maxStakedInPool[msg.sender][staking_id] += amount;
        emit staked(msg.sender, staking_id, stakeName);
    }

    function unlock(string memory staking_id,string memory stakeName)  isExist(staking_id) external {
        stakeInfo memory s = stakes[msg.sender][staking_id][stakeName];
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(s.rewards == 0 ){
            revert noRewards();
        }
        if(block.timestamp < s.stakedFromTS + p.duration){
            revert tooEarly();
        }
        if(s.graceStartedFromTS!= 0){
            revert alreadyUnlocked();
        }
        s.graceStartedFromTS = block.timestamp;
        stakes[msg.sender][staking_id][stakeName] = s;
        emit graceStarted(msg.sender,staking_id,stakeName);
    }

    function unstake(string memory staking_id,string memory stakeName) isExist(staking_id) public {
        stakeInfo memory s = stakes[msg.sender][staking_id][stakeName];
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(s.amountStaked == 0 ){
            revert noStaked();
        }
        if(block.timestamp <( s.graceStartedFromTS + p.gracePeriod ) || s.graceStartedFromTS == 0){
            revert graceNotFinished();
        }
        uint256 fees = s.amountStaked * p.unstakeFees / (100 *1e18);
        uint256 amount = s.amountStaked - fees;
        IERC20(p.stakingToken).transfer(feeAddress, fees);
        IERC20(p.stakingToken).transfer(msg.sender, amount);
        p.currentlyStaked -= s.amountStaked;
        maxStakedInPool[msg.sender][staking_id] -= s.amountStaked;
        s.amountStaked = 0;
        stakes[msg.sender][staking_id][stakeName] = s;
        AllStakingProfiles[staking_id] = p;
        emit unstaked(msg.sender,staking_id,stakeName);
    }

    function exit(string memory staking_id, string memory stakeName) isExist(staking_id)  external nonReentrant{
        stakeInfo memory s = stakes[msg.sender][staking_id][stakeName];
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(s.amountStaked == 0  && s.rewards == 0 ){
            revert noStakeOrRewards();
        }
        if(block.timestamp <( s.graceStartedFromTS + p.gracePeriod ) || s.graceStartedFromTS == 0){
            revert graceNotFinished();
        }
        uint256 fees = s.amountStaked * p.unstakeFees / (100 *1e18);
        uint256 amount = s.amountStaked - fees;
        IERC20(p.rewardToken).transfer(msg.sender, s.rewards);
        IERC20(p.stakingToken).transfer(msg.sender, amount);
        IERC20(p.stakingToken).transfer(feeAddress, fees);
        p.currentlyStaked -= s.amountStaked;
        maxStakedInPool[msg.sender][staking_id] -= s.amountStaked;
        s.rewards = 0;
        s.amountStaked = 0;
        stakes[msg.sender][staking_id][stakeName] = s;
        AllStakingProfiles[staking_id] = p;
        emit unstaked(msg.sender,staking_id,stakeName);
        emit claimed(msg.sender,staking_id,stakeName);
    }

    function claimRewards(string memory staking_id,string memory stakeName) isExist(staking_id) public nonReentrant{
        stakeInfo memory s = stakes[msg.sender][staking_id][stakeName];
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(s.rewards == 0 ){
            revert noRewards();
        }
        if(block.timestamp <( s.graceStartedFromTS + p.gracePeriod ) || s.graceStartedFromTS == 0){
            revert graceNotFinished();
        }

        IERC20(p.rewardToken).transfer(msg.sender, s.rewards);
        s.rewards = 0;
        stakes[msg.sender][staking_id][stakeName] = s;
        emit claimed(msg.sender,staking_id,stakeName);
    }
    //apr must be in wei
    function createNewStaking(
        string memory staking_id,
        address stakingToken,
        address rewardToken,
        uint256[2] calldata allocations,
        uint256 startTime,
        uint256 duration,
        uint256 apr,
        uint256 rewardAllocation,
        uint256 unstakeFeePercentage,
        uint256 gracePeriod
        ) external onlyAdmin(){
            StakingProfile memory p = AllStakingProfiles[staking_id];
            if(p.startTime!= 0){
                revert alreadyExist();
            }
            if(startTime == 0){
                revert invalidStartTime();
            }
            if(apr <3300000000){
                revert aprTooLow();
            }
            uint256 rewardRate = (apr / 100) / 3.154e7;
            p = StakingProfile(
                stakingToken,
                rewardToken,
                startTime,
                duration,
                rewardRate,
                rewardAllocation,
                rewardAllocation,
                allocations,
                0,
                0,
                unstakeFeePercentage,
                true,
                gracePeriod
            );
            AllStakingProfiles[staking_id] = p;
            IERC20(rewardToken).safeTransferFrom(msg.sender,address(this),rewardAllocation);
            emit stakingProfileCreated(staking_id);
        }

        
    function closeStakingProfile(string memory staking_id)external onlyAdmin{
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(p.startTime== 0){
                revert doesntExist();
        }
        p.active = false;
        IERC20(p.rewardToken).transfer(msg.sender, p.rewardsLeft);
        p.rewardAllocated -= p.rewardsLeft;
        p.rewardsLeft = 0;
        AllStakingProfiles[staking_id] = p;
        emit closedStaking(staking_id);
    }

    function fundStaking(string memory staking_id,uint256 amount) external onlyAdmin{
        StakingProfile memory p = AllStakingProfiles[staking_id];
        if(p.active == false){
            revert stakingClosed();
        }
        p.rewardAllocated+= amount;
        p.rewardsLeft += amount;
        IERC20(p.rewardToken).safeTransferFrom(msg.sender,address(this),amount);
    }
    
    function getMaxStakeable(string memory staking_id) public view returns (uint256){
        StakingProfile memory p = AllStakingProfiles[staking_id];
        uint256 maxAmount = p.rewardsLeft * 1e18 / p.duration / p.rewardRate;
        if(maxAmount < p.allocations[0]){
            revert poolFilled();
        }
        if (p.allocations[1] < maxAmount){
            return p.allocations[1];
        }
        return maxAmount;

    }

    function getMinStakeable(string memory staking_id) public view returns (uint256){
        StakingProfile memory p = AllStakingProfiles[staking_id];
        uint256 minAmount = 1 * 1e18 / p.duration / p.rewardRate + 1 ;
        uint256 maxAmount = p.rewardsLeft * 1e18 / p.duration / p.rewardRate;
        if(maxAmount < p.allocations[0]){
            revert poolFilled();
        }
        if(minAmount > p.allocations[0]){
            return minAmount;
        }
        return p.allocations[0];
    }

    constructor(address adminAddress,address feeaddress){
        //set admin to the contract creator
        adminList[adminAddress] = true;
        feeAddress = feeaddress;
    }

    function getApr(string memory staking_id) external view returns(uint256){
        uint256 apr = AllStakingProfiles[staking_id].rewardRate * 3.154e7 * 100;
        return apr;
    }

    function setFeeaddress(address _feeAddress) external{
        if(msg.sender != feeAddress){
            revert notFeeAddress();
        }
        feeAddress = _feeAddress;
    }

    modifier isExist(string memory staking_id){
        if(AllStakingProfiles[staking_id].startTime == 0){
                revert doesntExist();
        }
        _;
    }

}