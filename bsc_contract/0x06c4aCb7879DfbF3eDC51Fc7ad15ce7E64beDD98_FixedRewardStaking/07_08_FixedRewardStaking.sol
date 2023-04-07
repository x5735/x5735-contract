// SPDX-License-Identifier: None
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IInflexibleStaking.sol";

contract FixedRewardStaking is Ownable, IInflexibleStaking {
    using SafeERC20 for IERC20;

    uint256 public constant APR_DENOM = 1e4;
    uint256 constant SEC_IN_DAY = 86400;

    IERC20 public stakeToken;
    IERC20 public rewardToken;

    uint256 public apr;
    uint256 public phase2Apr;
    uint256 public stakingPhaseStart;
    uint256 public stakingPhaseEnd;
    uint256 public lockPhaseEnd;
    uint256 public rewardPhaseEnd;
    uint256 public stakingCap;

    mapping(address => bool) public blacklist;
    mapping(address => uint256) public userStakeAmount;
    uint256 public totalStaked;

    modifier inStakingPhase() {
        require(
            block.timestamp >= stakingPhaseStart &&
                block.timestamp < stakingPhaseEnd,
            "Staking phase already ended"
        );
        _;
    }

    modifier lockPhaseEnded() {
        require(block.timestamp > lockPhaseEnd, "Lock phase has not ended yet");
        _;
    }

    modifier notBlacklisted() {
        require(!blacklist[_msgSender()], "User blacklisted");
        _;
    }

    constructor(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _apr,
        uint256 _phase2apr,
        uint256 _stakingPhaseStart,
        uint256 _stakingDuration,
        uint256 _lockPhaseDuration,
        uint256 _rewardPhaseDuration,
        uint256 _stakingCap
    ) {
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        apr = _apr;
        phase2Apr = _phase2apr;
        stakingPhaseStart = _stakingPhaseStart;

        stakingPhaseEnd = _stakingPhaseStart + _stakingDuration;
        lockPhaseEnd =
            _stakingPhaseStart +
            _stakingDuration +
            _lockPhaseDuration;
        rewardPhaseEnd = lockPhaseEnd + _rewardPhaseDuration;
        stakingCap = _stakingCap;
    }

    function setBlacklist(
        address _user,
        bool _isBlacklisted
    ) external onlyOwner {
        blacklist[_user] = _isBlacklisted;
    }

    function withdrawReward() external onlyOwner {
        uint256 rewardBal = getTotalReward();

        rewardToken.transfer(_msgSender(), rewardBal);
    }

    function getTotalReward() internal view returns (uint256 rewardBal) {
        rewardBal = rewardToken.balanceOf(address(this));

        if (address(rewardToken) == address(stakeToken)) {
            rewardBal -= totalStaked;
        }

        return rewardBal;
    }

    function stake(uint256 _amount) external inStakingPhase notBlacklisted {
        totalStaked += _amount;
        require(totalStaked <= stakingCap, "Exceeded staking cap");

        userStakeAmount[_msgSender()] += _amount;
        stakeToken.transferFrom(_msgSender(), address(this), _amount);

        emit Stake(_msgSender(), _amount);
    }

    function pendingReward(address _user) public view returns (uint256 reward) {
        uint256 curr = block.timestamp;
        uint256 stakedAmount = userStakeAmount[_user];

        if (curr >= stakingPhaseEnd && curr < rewardPhaseEnd) {
            uint256 numRewardDay = (lockPhaseEnd - stakingPhaseEnd) /
                SEC_IN_DAY;
            reward = (stakedAmount * numRewardDay * apr) / APR_DENOM / 365;
        } else if (curr >= rewardPhaseEnd) {
            uint256 numRewardDay = (rewardPhaseEnd - stakingPhaseEnd) /
                SEC_IN_DAY;
            reward =
                (stakedAmount * numRewardDay * phase2Apr) /
                APR_DENOM /
                365;
        }
    }

    function unstake() external lockPhaseEnded notBlacklisted {
        address staker = _msgSender();
        uint256 stakedAmnt = userStakeAmount[staker];

        require(stakedAmnt > 0, "User has not staked");

        uint256 reward = pendingReward(staker);
        userStakeAmount[staker] = 0;
        require(reward <= getTotalReward(), "Not enough reward token");
        totalStaked -= stakedAmnt;

        if (reward > 0) {
            rewardToken.transfer(staker, reward);
        }
        stakeToken.transfer(staker, stakedAmnt);

        emit Unstake(staker, stakedAmnt);
    }

    function emergencyWithdraw() external lockPhaseEnded {
        uint256 stakedAmnt = userStakeAmount[_msgSender()];
        totalStaked -= stakedAmnt;
        stakeToken.transfer(_msgSender(), stakedAmnt);
    }
}