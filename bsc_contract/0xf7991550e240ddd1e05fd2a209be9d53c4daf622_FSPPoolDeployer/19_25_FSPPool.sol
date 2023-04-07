// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Interface/IRematic.sol";
import "../Interface/IFSPFactory.sol";
import "../Interface/IFSPPool.sol";

contract FSPPool is Ownable, ReentrancyGuard, IFSPPool {
    using SafeERC20 for IERC20Metadata;
    using SafeMath for uint256;

    // The address of the token to stake
    IERC20Metadata public stakedToken;

    // Number of reward tokens supplied for the pool
    uint256 public rewardSupply;

    // desired APY
    uint256 public APYPercent;

    // lock time of pool
    uint256 public lockTime;

    // Pool Create Time
    uint256 public poolStartTime;

    // Pool End Time
    uint256 public poolEndTime;

    // maximum number tokens that can be staked in the pool
    // uint256 public maxTokenSupply;

    // recent reflection received amount
    mapping(address => uint256) public Ra;

    // total withdrawn token amount
    uint256 private Tw;

    // total token added
    uint256 private To;

    // total token staked
    uint256 private TTs;

    // total token compounded
    uint256 private TTx;

    // total token harvested
    uint256 private TTv;

    // Reflection contract address if staked token has refection token (null address if none)
    IERC20Metadata public reflectionToken;

    // The reward token
    IERC20Metadata public rewardToken;

    // reflection token or not
    bool public isReflectionToken;

    // The address of the smart chef factory
    IFSPFactory SMART_CHEF_FACTORY;

    // Whether a limit is set for users
    bool public userLimit;

    // Whether it is initialized
    bool public isInitialized;

    bool public isPartition;

    bool public isPrivate;

    bool public isStopped;

    bool public forceStopped;

    // bool public restWithdrawnByOwner;

    bool public isRewardTokenTransfered;

    // The staked token amount limit per user (0 if none)
    uint256 public limitAmountPerUser;

    // Reward percent
    uint256 public rewardPercent;

    uint256 public stopTime;

    uint256 public totalRewardClaimedByStaker = 0;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    // claimable reflection amount of stakers
    mapping(address => uint256) public reflectionClaimable;

    mapping(address => bool) public isStakedUser;

    // whitelist for private pool
    mapping(address => bool) public whiteListForPrivatePool;

    bool public isInitialize;

    address public deployer;

    struct UserInfo {
        uint256 stakedAmount; // How many staked tokens the user has staked
        uint256 compoundAmount; // How many staked tokens the user has staked
        uint256 depositTime; // Deposit time
    }

    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewUserLimitAmount(uint256 poolLimitPerUser);
    event Withdraw(address indexed user, uint256 amount);
    event RewardClaim(address indexed user, uint256 amount);
    event ReflectionClaim(address indexed user, uint256 amount);
    event UpdateProfileAndThresholdPointsRequirement(
        bool isProfileRequested,
        uint256 thresholdPoints
    );

    event AddToken(address indexed user, uint256 amount);
    event PoolInialized();

    /**
     * @notice Constructor
     */
    constructor() {
        deployer = msg.sender;
    }

    modifier isPoolActive() {
        require(poolEndTime > block.timestamp && !isStopped, "pool is ended");
        _;
    }

    modifier onlyFSPPoolDeployer() {
        require(deployer == msg.sender, "Caller is not FSP pool deployer");
        _;
    }

    modifier onlyWhiteListAccount() {
        if(isPrivate) require(whiteListForPrivatePool[msg.sender], "Caller is not whitelisted");
        _;
    }

    /*
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _reflectionToken: _reflectionToken token address
     * @param _rewardSupply: Reward Supply Amount
     * @param _APYPercent: APY
     * @param _lockTimeType: Lock Time Type 
               0 - 1 year 
               1- 180 days 
               2- 90 days 
               3 - 30 days
     * @param _limitAmountPerUser: Pool limit per user in stakedToken
     * @param _isPartition:
     * @param _isPrivate:
     */
    function initialize(
        address _stakedToken,
        address _reflectionToken,
        uint256 _rewardSupply,
        uint256 _APYPercent,
        uint256 _lockTimeType,
        uint256 _limitAmountPerUser,
        bool _isPartition,
        bool _isPrivate
    ) external {
        require(!isInitialized, "Already initialized");
        require(msg.sender == address(SMART_CHEF_FACTORY), "Not factory");

        // Make this contract initialized
        isInitialized = true;

        stakedToken = IERC20Metadata(_stakedToken);
        reflectionToken = IERC20Metadata(_reflectionToken);
        APYPercent = _APYPercent;
        if (address(_reflectionToken) != address(0)) {
            isReflectionToken = true;
            reflectionToken = IERC20Metadata(_reflectionToken);
        }
        if (_limitAmountPerUser > 0) {
            userLimit = true;
            limitAmountPerUser = _limitAmountPerUser;
        }

        lockTime = _lockTimeType == 0 ? 365 days : _lockTimeType == 1
            ? 180 days
            : _lockTimeType == 2
            ? 90 days
            : 30 days;

        rewardPercent = _lockTimeType == 0 ? 100000 : _lockTimeType == 1
            ? 49310
            : _lockTimeType == 2
            ? 24650
            : 8291;

        // maxTokenSupply = (((_rewardSupply / _APYPercent) * 100) /
        //     rewardPercent) * 10**5;

        rewardSupply = _rewardSupply;
        isPartition = _isPartition;
        isPrivate = _isPrivate;
    }

    function rewardTokenTransfer() external onlyOwner {
        stakedToken.safeTransferFrom(msg.sender, address(this), rewardSupply);
        isRewardTokenTransfered = true;
        To += rewardSupply;

        isInitialize = true;
        poolStartTime = block.timestamp;
        poolEndTime = poolStartTime + lockTime;

        emit PoolInialized();
    }

    function addToken(uint256 _amount) external onlyOwner {
        require(!isInitialize, "Can't add token after i1nitilzed");

        stakedToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        To += _amount;
        emit AddToken(msg.sender, _amount);
    }

    function makeActive() external onlyOwner {
        isInitialize = true;
        poolStartTime = block.timestamp;
        poolEndTime = poolStartTime + lockTime;
        emit PoolInialized();
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to deposit
     */
    function deposit(
        uint256 _amount
    ) external payable nonReentrant isPoolActive onlyWhiteListAccount {
        require(
            isRewardTokenTransfered,
            "Pool owner didn't send the reward tokens"
        );
        require(
            msg.value >= getDepositFee(isReflectionToken),
            "deposit fee is not enough"
        );
        require(_amount <= _getRemainCapacity(), "exceed remain capacity");
        payable(SMART_CHEF_FACTORY.platformOwner()).transfer(msg.value);

        UserInfo storage user = userInfo[msg.sender];
        require(
            !userLimit || ((_amount + user.stakedAmount) <= limitAmountPerUser),
            "Deposit limit exceeded"
        );

        if (!isStakedUser[msg.sender]) {
            isStakedUser[msg.sender] = true;
        }

        if (_amount > 0) {
            stakedToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );

            if(user.stakedAmount == 0){
                Ra[msg.sender] = 0;
            }

            user.stakedAmount = user.stakedAmount + _amount;
            user.depositTime = block.timestamp;
        }

        if (address(stakedToken) == SMART_CHEF_FACTORY.RFXAddress()) {
            SMART_CHEF_FACTORY.updateTotalDepositAmount(
                msg.sender,
                _amount,
                true
            );
        } else {
            SMART_CHEF_FACTORY.updateTokenDepositAmount(
                address(stakedToken),
                msg.sender,
                _amount,
                true
            );
        }

        _calculateReflections(msg.sender);

        TTs += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /*
     * @notice Claim reflection tokens
     */

    function claimReflections() external payable nonReentrant {
        require(
            msg.value >= getReflectionFee(),
            "reflection fee is not enough"
        );
        require(isReflectionToken, "staked token don't have reflection token");

        payable(SMART_CHEF_FACTORY.platformOwner()).transfer(msg.value);

        uint256 rewardAmount = reflectionClaimable[msg.sender];

        require(rewardAmount > 0, "no reflection claimable tokens");

        _calculateReflections(msg.sender);

        reflectionToken.transfer(msg.sender, rewardAmount.mul(99).div(100));
        reflectionToken.transfer(
            address(SMART_CHEF_FACTORY),
            rewardAmount.mul(1).div(100)
        );

        // Ra[msg.sender] -= rewardAmount;

        reflectionClaimable[msg.sender] = 0;

        emit ReflectionClaim(msg.sender, rewardAmount);
    }

    function claimReward() external payable nonReentrant {
        require(
            msg.value >= getRewardClaimFee(isReflectionToken),
            "claim fee is not enough"
        );
        payable(SMART_CHEF_FACTORY.platformOwner()).transfer(msg.value);

        UserInfo storage user = userInfo[msg.sender];

        uint256 rewardAmount = _getRewardAmount(msg.sender);

        require(rewardAmount > 0, "There are no claimable tokens in this pool");

        if (isPartition) {
            IRematic(address(stakedToken)).transferTokenFromPool(
                msg.sender,
                rewardAmount
            );
        } else {
            stakedToken.safeTransfer(msg.sender, rewardAmount);
        }

        totalRewardClaimedByStaker += rewardAmount;
        (block.timestamp > stopTime && isStopped)
            ? user.depositTime = stopTime
            : user.depositTime = block.timestamp;

        _calculateReflections(msg.sender);

        emit RewardClaim(msg.sender, rewardAmount);
    }

    function compound() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 rewardAmount = _getRewardAmount(msg.sender);
        require(rewardAmount > 0, "There are no claimable tokens in this pool");
        user.compoundAmount += rewardAmount;
        (block.timestamp > stopTime && isStopped)
            ? user.depositTime = stopTime
            : user.depositTime = block.timestamp;
        _calculateReflections(msg.sender);
    }

    function withdraw() external payable nonReentrant {
        uint256 withdrawFee = (isStopped || poolEndTime < block.timestamp)
            ? getCanceledWithdrawFee(isReflectionToken)
            : getEarlyWithdrawFee(isReflectionToken);
        require(msg.value >= withdrawFee, "withdrawFee is not enough");
        payable(SMART_CHEF_FACTORY.platformOwner()).transfer(msg.value);

        UserInfo storage user = userInfo[msg.sender];
        uint256 wM = user.stakedAmount + user.compoundAmount;

        require(wM > 0, "No tokens have been deposited into this pool");

        _calculateReflections(msg.sender);

        stakedToken.safeTransfer(msg.sender, wM);

        if (address(stakedToken) == SMART_CHEF_FACTORY.RFXAddress()) {
            SMART_CHEF_FACTORY.updateTotalDepositAmount(msg.sender, 0, false);
        } else {
            SMART_CHEF_FACTORY.updateTokenDepositAmount(
                address(stakedToken),
                msg.sender,
                0,
                false
            );
        }
        isStakedUser[msg.sender] = false;
        Tw += wM;

        userInfo[msg.sender].stakedAmount = 0;
        userInfo[msg.sender].compoundAmount = 0;

        emit Withdraw(msg.sender, wM);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external {
        require(
            msg.sender == owner() ||
                SMART_CHEF_FACTORY.isPlatformOwner(msg.sender),
            "You are not Admin"
        );
        require(!isStopped, "Already Canceled");
        isStopped = true;
        stopTime = block.timestamp;
    }

    /*
     * @notice Update token amount limit per user
     * @dev Only callable by owner.
     * @param _userLimit: whether the limit remains forced
     * @param _limitAmountPerUser: new pool limit per user
     */
    function updatePoolLimitPerUser(
        bool _userLimit,
        uint256 _limitAmountPerUser
    ) external onlyOwner {
        require(userLimit, "Must be set");
        if (_userLimit) {
            require(
                _limitAmountPerUser > limitAmountPerUser,
                "New limit must be higher"
            );
            limitAmountPerUser = _limitAmountPerUser;
        } else {
            userLimit = _userLimit;
            limitAmountPerUser = 0;
        }
        emit NewUserLimitAmount(limitAmountPerUser);
    }

    function getDepositFee(bool _isReflection) public view returns (uint256) {
        return
            SMART_CHEF_FACTORY
                .getDepositFee(_isReflection)
                .mul(rewardPercent)
                .div(10 ** 5);
    }

    function getEarlyWithdrawFee(
        bool _isReflection
    ) public view returns (uint256) {
        return SMART_CHEF_FACTORY.getEarlyWithdrawFee(_isReflection);
    }

    function getCanceledWithdrawFee(
        bool _isReflection
    ) public view returns (uint256) {
        return
            SMART_CHEF_FACTORY
                .getCanceledWithdrawFee(_isReflection)
                .mul(rewardPercent)
                .div(10 ** 5);
    }

    function getRewardClaimFee(
        bool _isReflection
    ) public view returns (uint256) {
        return SMART_CHEF_FACTORY.getRewardClaimFee(_isReflection);
    }

    function getReflectionFee() public view returns (uint256) {
        return SMART_CHEF_FACTORY.getReflectionFee();
    }

    // function getMaxStakeTokenAmount() public view returns (uint256) {
    //     return maxTokenSupply;
    // }

    /*
     * @notice Return Total Staked Tokens
     */
    function getTotalStaked() public pure returns (uint256) {
        uint256 _totalStaked = 0;
        return _totalStaked;
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) public view returns (uint256) {
        return _getRewardAmount(_user);
    }

    /*
     * @notice Return reward amount of user.
     * @param _user: user address to calculate reward amount
     */
    function _getRewardAmount(address _user) internal view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 rStaked = user.stakedAmount + user.compoundAmount;
        uint256 rewardPerSecond = (
            ((rStaked.mul(APYPercent)).div(100)).mul(rewardPercent).div(10 ** 5)
        );
        uint256 rewardAmount;
        if (isStopped && stopTime < poolEndTime) {
            rewardAmount = rewardPerSecond
                .mul(stopTime.sub(user.depositTime))
                .div(lockTime);
        } else if (block.timestamp >= poolEndTime) {
            rewardAmount = rewardPerSecond
                .mul(poolEndTime.sub(user.depositTime))
                .div(lockTime);
        } else {
            rewardAmount = rewardPerSecond
                .mul(block.timestamp - user.depositTime)
                .div(lockTime);
        }
        return rewardAmount;
    }

    function _calculateReflections(address _account) internal {
        
        if (isReflectionToken) {
            uint256 Rp = reflectionToken.balanceOf(address(this));
            
            uint256 Tp = stakedToken.balanceOf(address(this));
            
            if (Rp > Ra[_account]) {
                uint256 totalToken = userInfo[_account].stakedAmount +
                    userInfo[_account].compoundAmount;
                
                uint256 Hr = totalToken * 10000 / ((Tp + Tw) - (To - (((block.timestamp - poolStartTime) * To) / lockTime)));

                reflectionClaimable[_account] += (Rp - Ra[_account]) * Hr / 10000;
                Ra[_account] = Rp;
            }
        }
    }

    /*
     * @notice Withdraw the rest staked and reflection token amount if pool is canceled
     * @dev only call by pool owner
     */

    function emergencyWithdrawByPoolOwner() external onlyOwner {
        require(
            poolEndTime < block.timestamp || isStopped,
            "pool is not ended yet"
        );
        // require(!restWithdrawnByOwner, "already withdrawn the rest staked and reflection token");
        uint256 totalStakedAmount = stakedToken.balanceOf(address(this));
        // restWithdrawnByOwner = true;
        stakedToken.safeTransfer(msg.sender, totalStakedAmount);
    }

    function emergencyWithdrawByPlatformOwner() external {
        require(
            SMART_CHEF_FACTORY.isPlatformOwner(msg.sender),
            "You are not Platform Owner"
        );

        if (isReflectionToken && !isPartition) {
            reflectionToken.transfer(
                msg.sender,
                reflectionToken.balanceOf(address(this))
            );
        }
        stakedToken.safeTransfer(
            msg.sender,
            stakedToken.balanceOf(address(this))
        );
        isStopped = true;
        forceStopped = true;
    }

    /*
     * @notice Return user limit is set or zero.
     */
    function hasUserLimit() public view returns (bool) {
        if (!userLimit) {
            return false;
        }

        return true;
    }

    /**
     * @notice Return the Pool Remaining Time.
     */
    function getPoolLifeTime() external view returns (uint256) {
        uint256 lifeTime = 0;

        if (poolEndTime > block.timestamp) {
            lifeTime = poolEndTime - block.timestamp;
        }

        return lifeTime;
    }

    /**
     * @notice Return Status of Pool
     */

    function getPoolStatus() external view returns (bool) {
        return isStopped || poolEndTime < block.timestamp;
    }

    function _getInitialCapacity() internal view returns (uint256) {
        uint256 Syr = 31536000;
        uint256 Ci = (To * Syr * 100) / (APYPercent * lockTime);
        return Ci;
    }

    function _getRemainCapacity() internal view returns (uint256) {
        uint256 Syr = 31536000;
        uint256 Pr = poolEndTime - block.timestamp;
        uint256 Cr1 = Syr * Pr * To * 100 / lockTime / (APYPercent * lockTime);
        uint256 Cr2 = Pr * (TTs + TTx - TTv) / lockTime;
        return Cr1 - Cr2;
    }

    function getInitialCapacity() external view returns (uint256) {
        return _getInitialCapacity();
    }

    function getRemainCapacity() external view returns (uint256) {
        return _getRemainCapacity();
    }

    function setFSPFactory(address _fspFactory) external onlyFSPPoolDeployer {
        SMART_CHEF_FACTORY = IFSPFactory(_fspFactory);
    }
    function transferOwnership(
        address newOwner
    ) public virtual override(IFSPPool, Ownable) onlyOwner {
        _transferOwnership(newOwner);
    }

    function whilteListBulkAccounts(address[] memory _addresses, bool flag) external onlyOwner {
        require(isPrivate, "Pool is not private!");
        for(uint256 i=0; i < _addresses.length; i++){
            if(whiteListForPrivatePool[_addresses[i]] != flag){
                whiteListForPrivatePool[_addresses[i]] = flag;
            }
        }
    }

    function whilteListAccount(address _address, bool flag) external onlyOwner {
        require(isPrivate, "same value already!");
        whiteListForPrivatePool[_address] = flag;
    }
}