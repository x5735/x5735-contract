// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

import "./StakingRewards.sol";

contract StakingRewardsFactory is Ownable {
	// immutables
	address public rewardsToken;
	uint256 public stakingRewardsGenesis;

	// the staking tokens for which the rewards contract has been deployed
	address[] public stakingTokens;

	// info about rewards for a particular staking token
	struct StakingRewardsInfo {
		address stakingRewards;
		uint256 rewardAmount;
		uint256 duration;
		uint256[] stakedTimeToClaim;
		uint256 timelock;
	}

	// rewards info by staking token
	mapping(address => StakingRewardsInfo)
		public stakingRewardsInfoByStakingToken;

	constructor(address _rewardsToken, uint256 _stakingRewardsGenesis)
		public
		Ownable()
	{
		require(
			_stakingRewardsGenesis >= block.timestamp,
			"StakingRewardsFactory::constructor: genesis too soon"
		);

		rewardsToken = _rewardsToken;
		stakingRewardsGenesis = _stakingRewardsGenesis;
	}

	///// permissioned functions

	// deploy a staking reward contract for the staking token, and store the reward amount
	// the reward will be distributed to the staking reward contract no sooner than the genesis
	function deploy(
		address stakingToken,
		uint256 rewardAmount,
		uint256 rewardsDuration,
		uint256[] memory stakedTimeToClaim,
		uint256 timelock
	) public onlyOwner {
		StakingRewardsInfo storage info =
			stakingRewardsInfoByStakingToken[stakingToken];
		require(
			info.stakingRewards == address(0),
			"StakingRewardsFactory::deploy: already deployed"
		);

		info.stakingRewards = address(
			new StakingRewards(
				/*_rewardsDistribution=*/
				address(this),
				rewardsToken,
				stakingToken,
				stakedTimeToClaim,
				timelock
			)
		);
		info.rewardAmount = rewardAmount;
		info.duration = rewardsDuration;
		stakingTokens.push(stakingToken);
	}

	function update(
		address stakingToken,
		uint256 rewardAmount,
		uint256 rewardsDuration,
		uint256[] memory stakedTimeToClaim,
		uint256 timelock
	) public onlyOwner {
		StakingRewardsInfo storage info =
			stakingRewardsInfoByStakingToken[stakingToken];
		require(
			info.stakingRewards != address(0),
			"StakingRewardsFactory::update: not deployed"
		);

		info.rewardAmount = rewardAmount;
		info.duration = rewardsDuration;
		info.stakedTimeToClaim = stakedTimeToClaim;
		info.timelock = timelock;
	}

	///// permissionless functions

	// call notifyRewardAmount for all staking tokens.
	function notifyRewardAmounts() public {
		require(
			stakingTokens.length > 0,
			"StakingRewardsFactory::notifyRewardAmounts: called before any deploys"
		);
		for (uint256 i = 0; i < stakingTokens.length; i++) {
			notifyRewardAmount(stakingTokens[i]);
		}
	}

	// notify reward amount for an individual staking token.
	// this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
	function notifyRewardAmount(address stakingToken) public {
		require(
			block.timestamp >= stakingRewardsGenesis,
			"StakingRewardsFactory::notifyRewardAmount: not ready"
		);

		StakingRewardsInfo storage info =
			stakingRewardsInfoByStakingToken[stakingToken];
		require(
			info.stakingRewards != address(0),
			"StakingRewardsFactory::notifyRewardAmount: not deployed"
		);

		if (info.rewardAmount > 0 && info.duration > 0) {
			uint256 rewardAmount = info.rewardAmount;
			uint256 duration = info.duration;
			info.rewardAmount = 0;
			info.duration = 0;

			require(
				IERC20(rewardsToken).transfer(
					info.stakingRewards,
					rewardAmount
				),
				"StakingRewardsFactory::notifyRewardAmount: transfer failed"
			);
			StakingRewards(info.stakingRewards).notifyRewardAmount(
				rewardAmount,
				duration
			);
		}
	}

	function pullExtraTokens(address token, uint256 amount) external onlyOwner {
		IERC20(token).transfer(msg.sender, amount);
	}
}