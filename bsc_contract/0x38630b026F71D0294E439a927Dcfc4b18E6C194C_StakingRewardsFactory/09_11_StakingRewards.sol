// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

interface IStakingRewards {
	// Views
	function lastTimeRewardApplicable() external view returns (uint256);

	function rewardPerToken() external view returns (uint256);

	function earned(address account) external view returns (uint256);

	function totalSupply() external view returns (uint256);

	function balanceOf(address account) external view returns (uint256);

	// Mutative

	function stake(uint256 amount) external;

	function withdraw(uint256 amount) external;

	function getReward() external;

	function exit() external;
}

/**
 * @dev Optional functions from the ERC20 standard.
 */
abstract contract ERC20Detailed is IERC20 {
	string private _name;
	string private _symbol;
	uint8 private _decimals;

	/**
	 * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
	 * these values are immutable: they can only be set once during
	 * construction.
	 */
	constructor(
		string memory name,
		string memory symbol,
		uint8 decimals
	) {
		_name = name;
		_symbol = symbol;
		_decimals = decimals;
	}

	/**
	 * @dev Returns the name of the token.
	 */
	function name() public view returns (string memory) {
		return _name;
	}

	/**
	 * @dev Returns the symbol of the token, usually a shorter version of the
	 * name.
	 */
	function symbol() public view returns (string memory) {
		return _symbol;
	}

	/**
	 * @dev Returns the number of decimals used to get its user representation.
	 * For example, if `decimals` equals `2`, a balance of `505` tokens should
	 * be displayed to a user as `5,05` (`505 / 10 ** 2`).
	 *
	 * Tokens usually opt for a value of 18, imitating the relationship between
	 * Ether and Wei.
	 *
	 * > Note that this information is only used for _display_ purposes: it in
	 * no way affects any of the arithmetic of the contract, including
	 * `IERC20.balanceOf` and `IERC20.transfer`.
	 */
	function decimals() public view returns (uint8) {
		return _decimals;
	}
}

abstract contract RewardsDistributionRecipient {
	address public rewardsDistribution;

	function notifyRewardAmount(uint256 reward, uint256 duration)
		external
		virtual;

	modifier onlyRewardsDistribution() {
		require(
			msg.sender == rewardsDistribution,
			"Caller is not RewardsDistribution contract"
		);
		_;
	}
}

contract StakingRewards is
	IStakingRewards,
	RewardsDistributionRecipient,
	ReentrancyGuard
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	/* ========== STATE VARIABLES ========== */
	struct ClaimUser {
		mapping(uint256 => bool) alreadyClaim;
	}
	IERC20 public rewardsToken;
	IERC20 public stakingToken;
	uint256 public periodFinish = 0;
	uint256 public rewardRate = 100;
	uint256 public lastUpdateTime;
	uint256 public rewardPerTokenStored;
	uint256[] public stakedTimeToClaim;
	uint256 public timelock;

	mapping(address => uint256) public userRewardPerTokenPaid;
	mapping(address => uint256) public rewards;

	uint256 private _totalSupply;
	mapping(address => uint256) private _balances;
	mapping(address => ClaimUser) internal claimUser;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		address _rewardsDistribution,
		address _rewardsToken,
		address _stakingToken,
		uint256[] memory _stakedTimeToClaim,
		uint256 _timelock
	) public {
		rewardsToken = IERC20(_rewardsToken);
		stakingToken = IERC20(_stakingToken);
		rewardsDistribution = _rewardsDistribution;
		stakedTimeToClaim = _stakedTimeToClaim;
		timelock = _timelock;
	}

	/* ========== VIEWS ========== */

	function totalSupply() external view override returns (uint256) {
		return _totalSupply;
	}

	function balanceOf(address account)
		external
		view
		override
		returns (uint256)
	{
		return _balances[account];
	}

	function lastTimeRewardApplicable() public view override returns (uint256) {
		return Math.min(block.timestamp, periodFinish);
	}

	function rewardPerToken() public view override returns (uint256) {
		if (_totalSupply == 0) {
			return rewardPerTokenStored;
		}
		return
			rewardPerTokenStored.add(
				lastTimeRewardApplicable()
					.sub(lastUpdateTime)
					.mul(rewardRate)
					.mul(1e18)
					.div(_totalSupply)
			);
	}

	function earned(address account) public view override returns (uint256) {
		return
			_balances[account]
				.mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
				.div(1e18)
				.add(rewards[account]);
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	// function stakeWithPermit(
	// 	uint256 amount,
	// 	uint256 deadline,
	// 	uint8 v,
	// 	bytes32 r,
	// 	bytes32 s
	// ) external nonReentrant updateReward(msg.sender) {
	// 	require(amount > 0, "Cannot stake 0");
	// 	_totalSupply = _totalSupply.add(amount);
	// 	_balances[msg.sender] = _balances[msg.sender].add(amount);

	// 	// permit
	// 	// IUniswapV2ERC20(address(stakingToken)).permit(msg.sender, address(this), amount, deadline, v, r, s);

	// 	stakingToken.safeTransferFrom(msg.sender, address(this), amount);
	// 	emit Staked(msg.sender, amount);
	// }

	function stake(uint256 amount)
		external
		override
		nonReentrant
		updateReward(msg.sender)
	{
		require(amount > 0, "Cannot stake 0");
		_totalSupply = _totalSupply.add(amount);
		_balances[msg.sender] = _balances[msg.sender].add(amount);
		stakingToken.safeTransferFrom(msg.sender, address(this), amount);
		emit Staked(msg.sender, amount);
	}

	function withdraw(uint256 amount)
		public
		override
		nonReentrant
		updateReward(msg.sender)
		onlyWithdrawIf
	{
		require(amount > 0, "Cannot withdraw 0");
		_totalSupply = _totalSupply.sub(amount);
		_balances[msg.sender] = _balances[msg.sender].sub(amount);
		stakingToken.safeTransfer(msg.sender, amount);
		emit Withdrawn(msg.sender, amount);
	}

	function getReward()
		public
		override
		nonReentrant
		updateReward(msg.sender)
		onlyClaimIf(stakedTimeToClaim)
	{
		uint256 reward = rewards[msg.sender];
		if (reward > 0) {
			rewards[msg.sender] = 0;
			rewardsToken.safeTransfer(msg.sender, reward);
			emit RewardPaid(msg.sender, reward);
		}
	}

	function exit() external override {
		withdraw(_balances[msg.sender]);
		getReward();
	}

	/* ========== RESTRICTED FUNCTIONS ========== */

	function notifyRewardAmount(uint256 reward, uint256 rewardsDuration)
		external
		override
		onlyRewardsDistribution
		updateReward(address(0))
	{
		require(
			block.timestamp.add(rewardsDuration) >= periodFinish,
			"Cannot reduce existing period"
		);

		if (block.timestamp >= periodFinish) {
			rewardRate = reward.div(rewardsDuration);
		} else {
			uint256 remaining = periodFinish.sub(block.timestamp);
			uint256 leftover = remaining.mul(rewardRate);
			rewardRate = reward.add(leftover).div(rewardsDuration);
		}

		// Ensure the provided reward amount is not more than the balance in the contract.
		// This keeps the reward rate in the right range, preventing overflows due to
		// very high values of rewardRate in the earned and rewardsPerToken functions;
		// Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
		uint256 balance = rewardsToken.balanceOf(address(this));
		require(
			rewardRate <= balance.div(rewardsDuration),
			"Provided reward too high"
		);

		lastUpdateTime = block.timestamp;
		periodFinish = block.timestamp.add(rewardsDuration);
		emit RewardAdded(reward, periodFinish);
	}

	/* ========== MODIFIERS ========== */

	modifier updateReward(address account) {
		rewardPerTokenStored = rewardPerToken();
		lastUpdateTime = lastTimeRewardApplicable();
		if (account != address(0)) {
			rewards[account] = earned(account);
			userRewardPerTokenPaid[account] = rewardPerTokenStored;
		}
		_;
	}
	modifier onlyWithdrawIf() {
		require(block.timestamp >= timelock, "Cannot withdraw yet");
		_;
	}
	modifier onlyClaimIf(uint256[] memory _stakedTimeToClaim) {
		bool successClaim;
		for (uint256 i = 0; i < _stakedTimeToClaim.length; i++) {
			if (
				block.timestamp >= _stakedTimeToClaim[i] &&
				!claimUser[msg.sender].alreadyClaim[_stakedTimeToClaim[i]]
			) {
				successClaim = true;
				claimUser[msg.sender].alreadyClaim[
					_stakedTimeToClaim[i]
				] = true;
			}
		}
		require(successClaim, "No time to claim yet");
		_;
	}

	/* ========== EVENTS ========== */

	event RewardAdded(uint256 reward, uint256 periodFinish);
	event Staked(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RewardPaid(address indexed user, uint256 reward);
}