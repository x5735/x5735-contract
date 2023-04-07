// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Credit to Olive.cash, Pancakeswap
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AutoRewardPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The timestamp of the last pool update
    uint256 public timestampLast;

    // The timestamp when REWARD mining ends.
    uint256 public timestampEnd;

    // REWARD tokens created per second.
    uint256 public rewardPerSecond;

    //Total wad staked;
    uint256 public totalStaked;

    uint256 public globalRewardDebt;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    uint256 public period = 7 days;

    mapping(address => uint256) public combinedStakedBalance;

    //rewards tracking
    uint256 public totalRewardsPaid;
    mapping(address => uint256) public totalRewardsReceived;

    // The reward token
    IERC20 public rewardToken =
        IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    // The staked token
    IERC20 public stakedToken;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => uint256) public userRewardDebt;
    event NewRewardPerSecond(uint256 rewardPerSecpmd);

    //do not receive rewards
    mapping(address => bool) isRewardExempt;

    bool isInitialized;

    function initialize(IERC20 _stakedToken, address _czusdPair)
        external
        onlyOwner
    {
        require(!isInitialized);
        isInitialized = true;
        stakedToken = _stakedToken;
        isRewardExempt[_czusdPair] = true;
        isRewardExempt[msg.sender] = true;

        PRECISION_FACTOR = uint256(
            10 **
                (uint256(30) -
                    (IERC20Metadata(address(rewardToken)).decimals()))
        );

        // Set the timestampLast as now
        timestampLast = block.timestamp;
    }

    function deposit(address _account, uint256 _amount) external {
        require(msg.sender == address(stakedToken), "ARP: Must be stakedtoken");
        _deposit(_account, _amount);
    }

    function withdraw(address _account, uint256 _amount) external {
        require(msg.sender == address(stakedToken), "ARP: Must be stakedtoken");
        _withdraw(_account, _amount);
    }

    function claim() external {
        _claimFor(msg.sender);
    }

    function _claimFor(address _account) internal {
        uint256 accountBal = combinedStakedBalance[_account];
        _updatePool();
        if (accountBal > 0) {
            uint256 pending = ((accountBal) * accTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_account];
            if (pending > 0) {
                rewardToken.safeTransfer(_account, pending);
                totalRewardsPaid += pending;
                totalRewardsReceived[_account] += (pending);
            }
            globalRewardDebt -= userRewardDebt[_account];
            userRewardDebt[_account] =
                (accountBal * accTokenPerShare) /
                PRECISION_FACTOR;
            globalRewardDebt += userRewardDebt[_account];
        }
    }

    function _deposit(address _account, uint256 _amount) internal {
        if (isRewardExempt[_account]) return;
        if (_amount == 0) return;
        _updatePool();
        if (combinedStakedBalance[_account] > 0) {
            uint256 pending = (combinedStakedBalance[_account] *
                accTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_account];
            if (pending > 0) {
                rewardToken.safeTransfer(_account, pending);
                totalRewardsPaid += pending;
                totalRewardsReceived[_account] += pending;
            }
        }
        globalRewardDebt -= userRewardDebt[_account];
        combinedStakedBalance[_account] += _amount;
        userRewardDebt[_account] =
            (combinedStakedBalance[_account] * accTokenPerShare) /
            PRECISION_FACTOR;
        globalRewardDebt += userRewardDebt[_account];
        totalStaked += _amount;
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function _withdraw(address _account, uint256 _amount) internal {
        if (isRewardExempt[_account]) return;
        if (_amount == 0) return;
        _updatePool();

        uint256 pending = (combinedStakedBalance[_account] * accTokenPerShare) /
            PRECISION_FACTOR -
            userRewardDebt[_account];
        if (pending > 0) {
            rewardToken.safeTransfer(_account, pending);
            totalRewardsPaid += pending;
            totalRewardsReceived[_account] += pending;
        }
        globalRewardDebt -= userRewardDebt[_account];
        combinedStakedBalance[_account] -= _amount;
        userRewardDebt[_account] =
            (combinedStakedBalance[_account] * accTokenPerShare) /
            PRECISION_FACTOR;
        globalRewardDebt += userRewardDebt[_account];
        totalStaked -= _amount;
    }

    function setIsRewardExempt(address _for, bool _to) public onlyOwner {
        if (isRewardExempt[_for] == _to) return;
        if (_to) {
            _withdraw(_for, combinedStakedBalance[_for]);
        } else {
            _deposit(_for, combinedStakedBalance[_for]);
        }
        isRewardExempt[_for] = _to;
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        if (block.timestamp > timestampLast && totalStaked != 0) {
            uint256 adjustedTokenPerShare = accTokenPerShare +
                ((rewardPerSecond *
                    _getMultiplier(timestampLast, block.timestamp) *
                    PRECISION_FACTOR) / totalStaked);
            return
                (combinedStakedBalance[_user] * adjustedTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_user];
        } else {
            return
                (combinedStakedBalance[_user] * accTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_user];
        }
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.timestamp <= timestampLast) {
            return;
        }

        if (totalStaked == 0) {
            timestampLast = block.timestamp;
            return;
        }

        accTokenPerShare =
            accTokenPerShare +
            ((rewardPerSecond *
                _getMultiplier(timestampLast, block.timestamp) *
                PRECISION_FACTOR) / totalStaked);

        uint256 totalRewardsToDistribute = rewardToken.balanceOf(
            address(this)
        ) +
            globalRewardDebt -
            ((accTokenPerShare * totalStaked) / PRECISION_FACTOR);
        if (totalRewardsToDistribute > 0) {
            rewardPerSecond = totalRewardsToDistribute / period;
            timestampEnd = block.timestamp + period;
        }
        timestampLast = block.timestamp;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to timestamp.
     * @param _from: timestamp to start
     * @param _to: timestamp to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        if (_to <= timestampEnd) {
            return _to - _from;
        } else if (_from >= timestampEnd) {
            return 0;
        } else {
            return timestampEnd - _from;
        }
    }
}