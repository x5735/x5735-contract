pragma solidity =0.5.16;

import "./interfaces/IBrewlabsPair.sol";
import "./interfaces/IBrewlabsLPFarm.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/ReentrancyGuard.sol";

contract BrewlabsLPFarm is IBrewlabsLPFarm, ReentrancyGuard {
    using SafeMath for uint256;

    address private manager; // lp farm admin
    address private brewlabsFeeTo; // brewlabs protocol fee treasury
    address private referrer;
    address private token0Owner; // token0 contract owner
    address private token1Owner; // token1 contract owner
    // address private referralContract;

    address public pair;
    address public token0;
    address public token1;
    address private tokenForHolderFee;

    address[] public stakersArray; // array to list lp holder
    mapping(address => uint256) staked; // keep lp balance of lp holders
    mapping(address => uint256) rewardsTable0; // last updated token0 rewards for lp holders
    mapping(address => uint256) rewardsTable1; // last updated token1 rewards for lp holders

    mapping(address => uint256) private balanceOfLpProvider; // fee token balance assigned to lp holders 
    mapping(address => uint256) private balanceOfBrewlabs; // fee token balance assigned to brewlabs treasury
    mapping(address => uint256) private balanceOfTokenOwner; // fee token balance assigned to token owner
    mapping(address => uint256) private balanceOfTokenHolder; // fee token balance assigned to token holder (similar to reflections)
    mapping(address => uint256) private balanceOfReferral; // fee token balance assigned to stakers of referral contract

    uint256 public accRewards0;
    uint256 public accRewards1;
    uint256 public lpSupply; // total LP token supply

    uint256 public timeToStartFarming;

    uint256 private lpFee;
    uint256 private brewlabsFee;
    uint256 private tokenOwnerFee;
    uint256 private tokenHolderFee;
    uint256 private referralFee;
    uint256 public operationFee; // total Fee (lpFee + brewlabsFee + tokenOwnerFee + tokenHolderFee + referralFee)

    modifier onlyPair() {
        require(msg.sender == pair, "Brewlabs LP Farm: INVALID_CALLER_PAIR");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == pair, "Brewlabs LP Farm: FORBIDDEN");
        _;
    }

    constructor(
        address _pair,
        address _token0,
        address _token1,
        address _manager,
        // address _referralContract,
        bytes memory feeDistribution
    ) public {
        (
            uint256 _lpFee,
            uint256 _brewlabsFee,
            uint256 _tokenOwnerFee,
            uint256 _tokenHolderFee,
            address _tokenForHolderFee, 
            uint256 _referralFee,
            address _referrer
        ) = abi.decode(
                feeDistribution,
                (uint256, uint256, uint256, uint256, address, uint256, address)
            );

        lpFee = _lpFee;
        brewlabsFee = _brewlabsFee;
        tokenOwnerFee = _tokenOwnerFee;
        tokenHolderFee = _tokenHolderFee;
        referralFee = _referralFee;
        operationFee =
            _lpFee +
            _brewlabsFee +
            _tokenOwnerFee +
            _tokenHolderFee +
            _referralFee;

        manager = _manager;
        referrer = _referrer;
        pair = _pair;
        token0 = _token0;
        token1 = _token1;
        tokenForHolderFee = _tokenForHolderFee;
        timeToStartFarming = block.timestamp + 3600 * 24;
    }

    function setManager(address _manager) external onlyManager {
        manager = _manager;
    }

    function setBrewlabsFeeTo(address _brewlabsFeeTo) external onlyManager {
        brewlabsFeeTo = _brewlabsFeeTo;
    }

    function setToken0Owner(address _token0Owner) external onlyManager {
        token0Owner = _token0Owner;
    }

    function setToken1Owner(address _token1Owner) external onlyManager {
        token1Owner = _token1Owner;
    }

    /**
     * @dev claim rewards for caller
     * this includes fees for lp provider, token holder, token owner, and brewlabs protocol
     * eligible caller can take his total claimable rewards
     */
    function claim() external nonReentrant {
        require(block.timestamp >= timeToStartFarming, "Brewlabs LP Farm: NOT_READY");
        _claimForLPHolder(msg.sender);
        _claimForTokenHolder(msg.sender);
        if (msg.sender == referrer) {
            _claimForReferral();
        }
        if (msg.sender == brewlabsFeeTo) {
            _claimForBrewlabs();
        }
        if (msg.sender == token0Owner) {
            _claimForTokenOwner(msg.sender, token0);
        }
        if (msg.sender == token1Owner) {
            _claimForTokenOwner(msg.sender, token1);
        }
    }

    /**
     * @dev deposit reward token from pair at the time of user trading.
     * @param token fee token address
     * @param amount fee token amount being deposited
     */
    function notifyRewardAmount(address token, uint256 amount)
        external
        onlyPair
    {
        require(amount > 0, "Brewlabs LP Farm: INSUFFICIENT_REWARD_AMOUNT");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balanceOfLpProvider[token] += amount.mul(lpFee).div(operationFee);
        balanceOfBrewlabs[token] += amount.mul(brewlabsFee).div(operationFee);
        balanceOfTokenOwner[token] += amount.mul(tokenOwnerFee).div(operationFee);
        balanceOfTokenHolder[token] += amount.mul(tokenHolderFee).div(operationFee);
        balanceOfReferral[token] += amount.mul(referralFee).div(operationFee);
    }

    /**
     * @dev update fee rewarding stats based on new minted lp token amount
     * @param to liquidity provider the lp newly being minted to
     */
    function minted(address to) external onlyPair {
        _udpateRewardsTable();
        _updateStakedInfo(to);
        _updateLPSupply();
    }

    /**
     * @dev update fee rewarding stats based on burnt lp token amount
     * @param from liquidity provider the lp being burnt from
     */
    function burned(address from) external onlyPair {
        _udpateRewardsTable();
        _updateStakedInfo(from);
        if (staked[from] == 0) {
            _claim(from);
        }
        _updateLPSupply();
    }

    /**
     * @dev view total pending reward for lp holder
     * @param staker lp holder
     */
    function pendingRewards(address staker)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 balance0 = balanceOfLpProvider[token0];
        uint256 balance1 = balanceOfLpProvider[token1];
        uint256 lpBalance = IBrewlabsPair(pair).balanceOf(staker);
        uint256 leftOver0 = balance0 - accRewards0;
        uint256 leftOver1 = balance1 - accRewards1;
        amount0 =
            rewardsTable0[staker] +
            leftOver0.mul(lpBalance).div(lpSupply);
        amount1 =
            rewardsTable1[staker] +
            leftOver1.mul(lpBalance).div(lpSupply);
    }

    function _claimForLPHolder(address _to) internal {
        _updateStakedInfo(_to);
        (uint256 amount0, uint256 amount1) = pendingRewards(_to);
        if (amount0 > 0 || amount1 > 0) {
            _udpateRewardsTable();
            // LP claim
            _claim(_to);
        }
    }

    function _claimForBrewlabs() internal {
        uint256 rewards0 = balanceOfBrewlabs[token0];
        uint256 rewards1 = balanceOfBrewlabs[token1];
        if (rewards0 > 0) {
            balanceOfBrewlabs[token0] = 0;
            IERC20(token0).transfer(brewlabsFeeTo, rewards0);
        }
        if (rewards1 > 0) {
            balanceOfBrewlabs[token1] = 0;
            IERC20(token1).transfer(brewlabsFeeTo, rewards1);
        }
    }

    function _claimForTokenOwner(address _to, address _token) internal {
        uint256 rewards = balanceOfTokenOwner[_token];
        if (rewards > 0) {
            balanceOfTokenOwner[_token] = 0;
            IERC20(_token).transfer(_to, rewards);
        }
    }

    function _claimForTokenHolder(address _to) internal {
        uint256 balance0 = IERC20(token0).balanceOf(_to);
        uint256 balance1 = IERC20(token1).balanceOf(_to);
        uint256 totalSupply0 = IERC20(token0).totalSupply();
        uint256 totalSupply1 = IERC20(token1).totalSupply();
        uint256 rewards0 = balanceOfTokenHolder[token0];
        uint256 rewards1 = balanceOfTokenHolder[token1];
        if (balance0 > 0 && rewards0 > 0) {
            uint256 amount = rewards0.mul(balance0).div(
                totalSupply0.sub(rewards0)
            );
            balanceOfTokenHolder[token0] -= amount;
            IERC20(token0).transfer(_to, amount);
        }
        if (balance1 > 0 && rewards1 > 0) {
            uint256 amount = rewards1.mul(balance1).div(
                totalSupply1.sub(rewards1)
            );
            balanceOfTokenHolder[token1] -= amount;
            IERC20(token1).transfer(_to, amount);
        }
    }

    function _claimForReferral() internal {
        uint256 rewards0 = balanceOfReferral[token0];
        uint256 rewards1 = balanceOfReferral[token1];
        if (rewards0 > 0) {
            balanceOfReferral[token0] = 0;
            IERC20(token0).transfer(referrer, rewards0);
        }
        if (rewards1 > 0) {
            balanceOfReferral[token1] = 0;
            IERC20(token1).transfer(referrer, rewards1);
        }
    }

    function _updateLPSupply() internal {
        lpSupply = IBrewlabsPair(pair).totalSupply();
    }

    function _updateStakedInfo(address to) internal {
        staked[to] = IBrewlabsPair(pair).balanceOf(to);
    }

    function _udpateRewardsTable() internal {
        uint256 balance0 = balanceOfLpProvider[token0];
        uint256 balance1 = balanceOfLpProvider[token1];
        uint256 leftOver0 = balance0 - accRewards0;
        uint256 leftOver1 = balance1 - accRewards1;
        for (uint256 i; i < stakersArray.length; i++) {
            address staker = stakersArray[i];
            uint256 amount0Plus = leftOver0.mul(staked[staker]).div(lpSupply);
            uint256 amount1Plus = leftOver1.mul(staked[staker]).div(lpSupply);
            rewardsTable0[staker] += amount0Plus;
            rewardsTable1[staker] += amount1Plus;
            accRewards0 += amount0Plus;
            accRewards1 += amount1Plus;
        }
    }

    function _claim(address to) internal {
        uint256 claimAmount0 = rewardsTable0[to];
        uint256 claimAmount1 = rewardsTable1[to];
        accRewards0 -= claimAmount0;
        accRewards1 -= claimAmount1;
        rewardsTable0[to] = 0;
        rewardsTable1[to] = 0;
        if (claimAmount0 > 0) {
            balanceOfLpProvider[token0] -= claimAmount0;
            IERC20(token0).transfer(to, claimAmount0);
        }
        if (claimAmount1 > 0) {
            balanceOfLpProvider[token1] -= claimAmount1;
            IERC20(token1).transfer(to, claimAmount1);
        }
        emit Claimed(to, claimAmount0, claimAmount1);
    }
}