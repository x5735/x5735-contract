// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/ICakePool.sol";
import "./interfaces/IPancakeProfile.sol";

contract TradingFeeRebate is Ownable, Pausable {
    using SafeERC20 for IERC20;

    /// @dev cakePool address
    address public immutable cakePoolAddress;
    /// @dev pancakeProfile address
    address public immutable pancakeProfileAddress;
    /// @dev the maximum value between start and claim time in a campaign
    uint256 public maxCampaignPeriod;
    /// @dev the minimum value between claim and claim end time in a campaign
    uint256 public minCampaignClaimPeriod;
    /// @dev the maximum value between claim and claim end time in a campaign
    uint256 public maxCampaignClaimPeriod;

    /// @notice Represents a reward incentive
    struct Incentive {
        uint256 totalRewardUnclaimed;
        uint256 totalReward;
        uint256 totalVolume;
        bytes32 proofRoot;
        uint256 campaignStart;
        uint256 campaignClaimTime;
        uint256 campaignClaimEndTime;
        uint256 thresholdLockedTime;
        uint256 thresholdLockedAmount;
        bool needProfileIsActivated;
        bool isActivated;
        bool isDynamicReward;
        uint16 dynamicRate;
    }

    /// @dev mapping the reward token of each incentive
    mapping(string => address) public rewardTokens;

    /// @dev this is the minimum value of amountUSD, lower than this value will not count into totalVolume
    mapping(string => uint256) public minAmountUSDs;

    /// @dev string refers to the value of campaignId
    mapping(string => Incentive) public incentives;

    /// @dev array of campaign Ids of all incentives
    string[] private incentiveCampaignIds;

    uint256 internal constant DYNAMIC_REWARD_DENOMINATOR = 10000;

    /// @dev mapping [user][token][claimed]
    mapping(address => mapping(address => uint256)) public userClaimedRecords;

    mapping(string => mapping(address => bool)) public userClaimedIncentives;

    event IncentiveCreated(string campaignId, address rewardToken, uint256 campaignStart, uint256 campaignClaimTime, uint256 campaignClaimEndTime, uint256 thresholdLockedTime, uint256 thresholdLockedAmount, bool needProfileIsActivated);
    event IncentivePrepared(string campaignId, uint256 totalVolume, uint256 minAmountUSD);
    event IncentiveRewardDeposited(string campaignId, uint256 amount, bool isDynamicReward, uint16 dynamicRate);
    event IncentiveActivated(string campaignId);
    event WithdrawAll(string campaignId, uint256 amount);
    event MaxCampaignPeriodUpdated(uint256 maxPeriod);
    event MinCampaignClaimPeriodUpdated(uint256 minClaimPeriod);
    event MaxCampaignClaimPeriodUpdated(uint256 maxClaimPeriod);
    event RewardClaimed(string campaignId, address indexed sender, uint256 amount);
    event Pause();
    event Unpause();

    constructor(address _cakePoolAddress, address _pancakeProfileAddress) {
        cakePoolAddress = _cakePoolAddress;
        pancakeProfileAddress = _pancakeProfileAddress;

        // init max period
        maxCampaignPeriod = 30 days;
        // init min claim period
        minCampaignClaimPeriod = 10 minutes;
        // init max claim period
        maxCampaignClaimPeriod = 30 days;
    }

    /// @dev Create an incentive, can be called by owner only
    /// @param _campaignId the campaignId of the incentive
    /// @param _rewardToken the reward token of the incentive
    /// @param _campaignStart the incentive start time
    /// @param _campaignClaimTime the incentive end time
    /// @param _campaignClaimEndTime the incentive end claim time, after this time user can't reward this incentive
    /// @param _thresholdLockedTime the threshold of CAKE locked time
    /// @param _thresholdLockedAmount the threshold of CAKE locked amount
    /// @param _needProfileIsActivated the flag of profile is active needed or not
    function createIncentive(
        string calldata _campaignId,
        address _rewardToken,
        uint256 _campaignStart,
        uint256 _campaignClaimTime,
        uint256 _campaignClaimEndTime,
        uint256 _thresholdLockedTime,
        uint256 _thresholdLockedAmount,
        bool _needProfileIsActivated
    ) external onlyOwner {
        require(_campaignStart > block.timestamp, "campaignStart must be exceed than now");
        require(_campaignClaimTime > _campaignStart, "campaignClaimTime must be exceed than campaignStart");
        require(_campaignStart < maxCampaignPeriod+block.timestamp, "period too long");
        require(_campaignClaimTime - _campaignStart < maxCampaignPeriod, "period too long");
        if (_campaignClaimEndTime > 0) {
            require(_campaignClaimEndTime - _campaignClaimTime > minCampaignClaimPeriod, "claim period too short");
            require(_campaignClaimEndTime - _campaignClaimTime < maxCampaignClaimPeriod, "claim period too long");
        }
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.campaignClaimTime == 0, "incentive exists");
        require(_rewardToken != address(0), "reward token address non-exist");
        rewardTokens[_campaignId] = _rewardToken;
        incentiveInstance.totalRewardUnclaimed = 0;
        incentiveInstance.totalReward = 0;
        incentiveInstance.totalVolume = 0;
        incentiveInstance.proofRoot = bytes32(0);
        incentiveInstance.campaignStart = _campaignStart;
        incentiveInstance.campaignClaimTime = _campaignClaimTime;
        incentiveInstance.campaignClaimEndTime = _campaignClaimEndTime;
        incentiveInstance.thresholdLockedTime = _thresholdLockedTime;
        incentiveInstance.thresholdLockedAmount = _thresholdLockedAmount;
        incentiveInstance.needProfileIsActivated = _needProfileIsActivated;
        incentiveInstance.isActivated = false;
        incentiveInstance.isDynamicReward = false;
        incentiveInstance.dynamicRate = 0;

        // push into Id array
        incentiveCampaignIds.push(_campaignId);

        emit IncentiveCreated(_campaignId, _rewardToken, _campaignStart, _campaignClaimTime, _campaignClaimEndTime, _thresholdLockedTime, _thresholdLockedAmount, _needProfileIsActivated);
    }

    /// @dev Prepare a created incentive, can be called by owner only
    /// @param _campaignId the campaignId of the incentive
    /// @param _totalVolume the total volume from swap transactions in this period of incentive
    /// @param _proofRoot the proof root of the merkle tree
    function prepareIncentive(
        string calldata _campaignId,
        uint256 _totalVolume,
        bytes32 _proofRoot,
        uint256 _minAmountUSD
    ) external onlyOwner {
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.campaignClaimTime != 0, "incentive non-exist");
        require(!incentiveInstance.isActivated, "incentive activated");
        require(_totalVolume > 0, "total volume should exceeds 0");
        incentiveInstance.totalVolume = _totalVolume;
        incentiveInstance.proofRoot = _proofRoot;

        // update amountUSD
        minAmountUSDs[_campaignId] = _minAmountUSD;

        emit IncentivePrepared(_campaignId, _totalVolume, _minAmountUSD);
    }

    /// @dev Deposit reward token into a created incentive, can be called by owner only
    /// @param _campaignId the campaignId of the incentive
    /// @param _amount the total number of reward transfer into this contract
    /// @param _isDynamicReward the flag of dynamic incentive or not
    /// @param _dynamicRate the rate of dynamic incentive from total volume
    function depositIncentiveReward(string calldata _campaignId, uint256 _amount, bool _isDynamicReward, uint16 _dynamicRate) external onlyOwner {
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.campaignClaimTime != 0, "incentive non-exist");
        require(!incentiveInstance.isActivated, "incentive activated");
        if (_isDynamicReward) {
            require(_dynamicRate > 0 && _dynamicRate <= DYNAMIC_REWARD_DENOMINATOR, "dynamic rate out of range");
            require(block.timestamp >= incentiveInstance.campaignClaimTime, "incentive non-ended");
            require(incentiveInstance.totalReward + _amount <= incentiveInstance.totalVolume * _dynamicRate / DYNAMIC_REWARD_DENOMINATOR, "dynamic reward too much");
        }
        incentiveInstance.totalRewardUnclaimed = incentiveInstance.totalRewardUnclaimed + _amount;
        incentiveInstance.totalReward = incentiveInstance.totalReward + _amount;
        incentiveInstance.isDynamicReward = _isDynamicReward;
        incentiveInstance.dynamicRate = _dynamicRate;

        // reward transfer
        IERC20(rewardTokens[_campaignId]).safeTransferFrom(msg.sender, address(this), _amount);

        emit IncentiveRewardDeposited(_campaignId, _amount, _isDynamicReward, _dynamicRate);
    }

    /// @dev Activate a created incentive, can be called by owner only
    /// @param _campaignId the campaignId of the incentive
    function activateIncentive(string calldata _campaignId) external onlyOwner {
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.proofRoot != bytes32(0), "incentive proof empty");
        require(incentiveInstance.campaignClaimTime != 0, "incentive non-exist");
        require(incentiveInstance.totalReward > 0, "incentive reward empty");
        require(!incentiveInstance.isActivated, "incentive activated");

        // activate incentive
        incentiveInstance.isActivated = true;

        emit IncentiveActivated(_campaignId);
    }

    /// @dev Calculate a user can claim reward base on input volume, not practical he can claim in number.
    /// This is not going to verify with merkle proof.
    /// @param _campaignId the campaignId of the incentive
    /// @param _selfVolume the volume in the period of the incentive
    /// @return amount calculate by totalReward * selfVol / totalVol
    function canClaim(string calldata _campaignId, uint256 _selfVolume) public view returns (uint256 amount) {
        if (_checkQualified(_campaignId) && !userClaimedIncentives[_campaignId][msg.sender]) {

            Incentive memory incentiveInstance = incentives[_campaignId];

            if (incentiveInstance.campaignClaimEndTime == 0 || incentiveInstance.campaignClaimEndTime > block.timestamp ) {
                // calculate the reward
                if (!incentiveInstance.isDynamicReward) {
                    amount = incentiveInstance.totalReward * _selfVolume / incentiveInstance.totalVolume;
                } else {
                    amount = incentiveInstance.dynamicRate * _selfVolume / DYNAMIC_REWARD_DENOMINATOR;
                }
            }
        }
    }

    /// @dev Return array of all the reward user can claim base on input volumes, not practical he can claim in number.
    /// @param _campaignIds the array of campaignId of the incentive
    /// @param _selfVolumes the array of volume in the period of the incentive
    function canClaimMulti(string[] calldata _campaignIds, uint256[] calldata _selfVolumes) external view returns (uint256[] memory amounts) {
        require(_campaignIds.length == _selfVolumes.length, "parameters length not same");

        // calculate each amount in array
        uint256 len = _campaignIds.length;
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            amounts[i] = canClaim(_campaignIds[i], _selfVolumes[i]);
        }
    }

    /// @dev A user can claim reward when the incentive is ended
    /// @param _campaignId the campaignId of the incentive
    /// @param _merkleProof the merkle proof from user's address and volume
    /// @param _selfVolume the volume in the period of the incentive
    function claimReward(string calldata _campaignId, bytes32[] calldata _merkleProof, uint256 _selfVolume) public whenNotPaused {
        require(_selfVolume > 0, "volume can't be negative");
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.campaignClaimTime < block.timestamp, "too early");
        require(incentiveInstance.isActivated, "incentive not activated");
        require(incentiveInstance.totalReward > 0, "incentive is non-exist");
        if (incentiveInstance.campaignClaimEndTime > 0) {
            require(incentiveInstance.campaignClaimEndTime > block.timestamp, "incentive has over claim end time");
        }
        require(_checkQualified(_campaignId), "user non-qualified");
        require(!userClaimedIncentives[_campaignId][msg.sender], "user already claimed this incentive");
        bytes32 leaf = keccak256(abi.encodePacked(
                msg.sender,
                _selfVolume
            )
        );
        require(MerkleProof.verify(_merkleProof, incentiveInstance.proofRoot, leaf), "invalid merkle proof");

        // calculate the reward
        uint256 amount = 0;
        if (!incentiveInstance.isDynamicReward) {
            amount = incentiveInstance.totalReward * _selfVolume / incentiveInstance.totalVolume;
        } else {
            amount = incentiveInstance.dynamicRate * _selfVolume / DYNAMIC_REWARD_DENOMINATOR;
        }
        require(incentiveInstance.totalRewardUnclaimed >= amount, "incentive balance is not enough");

        // update incentive mapping
        incentiveInstance.totalRewardUnclaimed = incentiveInstance.totalRewardUnclaimed - amount;

        address rewardToken = rewardTokens[_campaignId];
        // update record mapping
        userClaimedRecords[msg.sender][rewardToken] += amount;

        // update user claimed incentives
        userClaimedIncentives[_campaignId][msg.sender] = true;

        // reward transfer
        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        emit RewardClaimed(_campaignId, msg.sender, amount);
    }

    /// @dev A user can claim reward from incentive array when they are all ended
    /// @param _campaignIds the array of campaignId of the incentive
    /// @param _merkleProofs the array of merkle proof from user's address and volume
    /// @param _selfVolumes the array of volume in the period of the incentive
    function claimRewardMulti(string[] calldata _campaignIds, bytes32[][] calldata _merkleProofs, uint256[] calldata _selfVolumes) external {
        uint256 len = _campaignIds.length;
        require(len == _merkleProofs.length, "parameters length not same");
        require(len == _selfVolumes.length, "parameters length not same");

        for (uint256 i = 0; i < len; i++) {
            claimReward(_campaignIds[i], _merkleProofs[i], _selfVolumes[i]);
        }
    }

    /// @dev Withdraw all the reward in some cases, can be called by owner only
    /// @param _campaignId the campaignId of the incentive
    function withdrawAll(string calldata _campaignId) external onlyOwner {
        Incentive storage incentiveInstance = incentives[_campaignId];
        require(incentiveInstance.totalRewardUnclaimed > 0, "incentive balance is empty");
        uint256 amount = incentiveInstance.totalRewardUnclaimed;
        incentiveInstance.totalRewardUnclaimed = 0;
        incentiveInstance.totalReward -= amount;
        incentiveInstance.isActivated = false;
        require(amount >= 0, "incentive unclaimed reward empty");

        // reward transfer
        IERC20(rewardTokens[_campaignId]).safeTransfer(msg.sender, amount);

        emit WithdrawAll(_campaignId, amount);
    }

    /// @dev Update the period of campaign between start and claim time.
    /// @param _maxPeriod the value of maxCampaignPeriod
    function updateMaxCampaignPeriod(uint256 _maxPeriod) external onlyOwner {
        maxCampaignPeriod = _maxPeriod; // update

        emit MaxCampaignPeriodUpdated(_maxPeriod);
    }

    /// @dev Update the period of campaign claim between claim and claim end time.
    /// @param _minClaimPeriod the value of minCampaignClaimPeriod
    function updateMinCampaignClaimPeriod(uint256 _minClaimPeriod) external onlyOwner {
        minCampaignClaimPeriod = _minClaimPeriod; // update

        emit MinCampaignClaimPeriodUpdated(_minClaimPeriod);
    }

    /// @dev Update the period of campaign claim between claim and claim end time.
    /// @param _maxClaimPeriod the value of maxCampaignClaimPeriod
    function updateMaxCampaignClaimPeriod(uint256 _maxClaimPeriod) external onlyOwner {
        maxCampaignClaimPeriod = _maxClaimPeriod; // update

        emit MaxCampaignClaimPeriodUpdated(_maxClaimPeriod);
    }

    /**
     * @notice Triggers stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
        emit Pause();
    }

    /**
     * @notice Returns to normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
        emit Unpause();
    }

    /// @dev CleanUp incentiveCampaignIds, erase test data, can be called by owner only
    function cleanUpIncentiveCampaignIds() external onlyOwner {
        // delete it
        delete incentiveCampaignIds;
    }

    /// @dev return all incentive campaign Id array
    function getIncentiveCampaignIds() external view returns (string[] memory) {
        return incentiveCampaignIds;
    }

    /// @dev return user total claimed reward by sender
    function getTotalClaimedReward(address _token, address sender) external view returns (uint256) {
        return userClaimedRecords[sender][_token];
    }

    // @dev Check if the user is qualified to claim reward
    function _checkQualified(string memory _campaignId) internal view returns (bool) {
        Incentive memory incentiveInstance = incentives[_campaignId];

        if (incentiveInstance.needProfileIsActivated) {
            bool isActive = IPancakeProfile(pancakeProfileAddress).getUserStatus(msg.sender);
            if (!isActive) {
                return false;
            }
        }
        (, , , , , uint256 lockEndTime, , , uint256 lockedAmount) = ICakePool(cakePoolAddress).userInfo(msg.sender);
        if (lockEndTime-incentiveInstance.campaignClaimTime >= incentiveInstance.thresholdLockedTime &&
            lockedAmount >= incentiveInstance.thresholdLockedAmount) {
            return true;
        }
        return false;
    }
}