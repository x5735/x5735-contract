// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './ILaunchpadCore.sol';
import './Extension/ILaunchpadSimpleDelegate.sol';
import './Extension/ILaunchpadPooledDelegate.sol';
import './Extension/ILaunchpadFeeDecider.sol';
import "./Extension/FeeCollector.sol";
import "./Extension/ILaunchpadFeeDecider.sol";
import '../Token/IERC20Delegated.sol';

/**
 * @title Token Factory
 * @dev BEP20 compatible token.
 */
contract LaunchpadCore is Ownable, AccessControl, FeeCollector, ILaunchpadCore {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant MIN = 0;

    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
    bytes32 public constant AGENT_ROLE = keccak256('AGENT_ROLE');

    struct UserInfo {
        uint256 baseAmount;
        uint256 pairAmount;
        uint256 mintAmount;
        uint256 lockedSince;
        uint256 lockedUntil;
        uint256 releaseTimestamp;
        uint256 releaseTimerange;
        bool isLocked;
    }

    mapping(address => UserInfo) public userInfo;
    uint256 userSize;

    IERC20 public baseToken;
    IERC20 public pairToken;
    IERC20Delegated public mintToken;

    uint256 public precWeight;
    uint256 public baseWeight;
    uint256 public baseMaxWeight;
    uint256 public pairWeight;
    uint256 public pairMaxWeight;
    uint256 public multWeight;
    uint256 public distWeight;

    struct DelegateInfo {
        address addr;
        uint256 mode;
        uint256 pool;
        uint256 deposited;
    }

    uint256 public startBlock;
    uint256 public closeBlock;
    
    uint256[2] public totalValue;
    uint256[2] public feeClaimed;
    uint256[2] public feeAwarded;

    uint256 public minLockTime;
    uint256 public maxLockTime;
    uint256 public maxRewardTime;
    uint256 public releaseTime;

    ILaunchpadFeeDecider public instantReleasesFeeDecider;
    ILaunchpadFeeDecider public instantWithdrawFeeDecider;
    ILaunchpadFeeDecider public exitFeeDecider;
    bool private _paused;

    event Deposited(address indexed user, uint256 baseAmount, uint256 pairAmount);
    event Withdrawn(address indexed user, uint256 baseAmount, uint256 pairAmount);
    event WithdrawnRemaining(address indexed user, uint256 baseAmount, uint256 pairAmount);
    event WithdrawnFeeValues(address indexed user, uint256 baseAmount, uint256 pairAmount);
    event AllocatedFeeValues(address indexed user, uint256 baseAmount, uint256 pairAmount);
    event RewardMinted(address indexed user, uint256 mintAmount);
    event RewardBurned(address indexed user, uint256 mintAmount);
    event FactoryStarted(uint256 block);
    event FactoryStopped(uint256 block);
    event TokenAddressChanged(address indexed baseToken, address indexed pairToken, address indexed mintToken);
    event TokenWeightsChanged(uint256 weigtht0, uint256 weigtht1, uint256 weight2, uint256 weight3, uint256 weight4);
    event TotalWeightsChanged(uint256 weigtht0, uint256 weigtht1);
    event LockIntervalChanged(uint256 minLock, uint256 maxLock, uint256 maxReward, uint256 release);
    event FarmingAddressChanged(address indexed addr, uint256 mode, uint256 pool);
    event StakingAddressChanged(address indexed addr, uint256 mode, uint256 pool);
    event LockRenewed(address indexed user, uint256 timestamp);
    event LockDeleted(address indexed user, uint256 timestamp);
    event PaidReleasesFeeDeciderChanged(address indexed addr);
    event PaidWithdrawFeeDeciderChanged(address indexed addr);
    event ExitFeeDeciderChanged(address indexed addr);
    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        transferOwnership(_msgSender());
        _paused = true;

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(AGENT_ROLE, ADMIN_ROLE);

        _setupRole(ADMIN_ROLE, address(this));
    }

    function setAgent(address account, bool status) external onlyOwner returns (bool) {
        bytes4 selector = status ? this.grantRole.selector : this.revokeRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, AGENT_ROLE, account));
        return true;
    }

    function isAgent(address account) external view returns (bool) {
        return hasRole(AGENT_ROLE, account);
    }

    function setTokenAddress(IERC20 _baseToken, IERC20 _pairToken, IERC20Delegated _mintToken) public onlyOwner {
        require(address(_baseToken) != address(0), 'Factory: token address needs to be different than zero!');
        require(address(_pairToken) != address(0), 'Factory: token address needs to be different than zero!');
        require(address(_mintToken) != address(0), 'Factory: token address needs to be different than zero!');
        require(address(baseToken) == address(0), 'Factory: tokens already set!');
        require(address(pairToken) == address(0), 'Factory: tokens already set!');
        require(address(mintToken) == address(0), 'Factory: tokens already set!');
        baseToken = _baseToken;
        pairToken = _pairToken;
        mintToken = _mintToken;
        emit TokenAddressChanged(address(baseToken), address(pairToken), address(mintToken));
    }

    function setTotalWeights(uint256 _multWeight, uint256 _distWeight) public onlyOwner {
        require(_multWeight > 0 && _distWeight > 0, 'Factory: weights need to be higher than zero!');
        multWeight = _multWeight;
        distWeight = _distWeight;
        emit TotalWeightsChanged(multWeight, distWeight);
    }

    function setTokenWeights(uint256 _precWeight, uint256 _baseWeight, uint256 _pairWeight, uint256 _baseMaxWeight, uint256 _pairMaxWeight) public onlyOwner {
        require(_baseWeight > 0 && _pairWeight > 0, 'Factory: weights need to be higher than zero!');
        precWeight = _precWeight;
        baseWeight = _baseWeight;
        pairWeight = _pairWeight;
        baseMaxWeight = _baseMaxWeight;
        pairMaxWeight = _pairMaxWeight;
        emit TokenWeightsChanged(precWeight, baseWeight, pairWeight, baseMaxWeight, pairMaxWeight);
    }

    function setLockInterval(uint256 _minLock, uint256 _maxLock, uint256 _maxRewardTime, uint256 _release) public onlyOwner {
        require(_maxLock > 0 && _maxRewardTime > 0, 'Factory: maxLock time needs to be higher than zero!');
        minLockTime = _minLock;
        maxLockTime = _maxLock;
        maxRewardTime = _maxRewardTime;
        releaseTime = _release;
        emit LockIntervalChanged(minLockTime, maxLockTime, maxRewardTime, releaseTime);
    }

    function setPaidReleasesFeeDecider(ILaunchpadFeeDecider addr) public onlyOwner {
        require(address(addr) != address(0), 'Factory: paid release fee decider address needs to be different from zero!');
        instantReleasesFeeDecider = addr;
        emit PaidReleasesFeeDeciderChanged(address(addr));
    }

    function setPaidWithdrawFeeDecider(ILaunchpadFeeDecider addr) public onlyOwner {
        require(address(addr) != address(0), 'Factory: paid withdraw fee decider address needs to be different from zero!');
        instantWithdrawFeeDecider = addr;
        emit PaidWithdrawFeeDeciderChanged(address(addr));
    }

    function setExitFeeDecider(ILaunchpadFeeDecider addr) public onlyOwner {
        require(address(addr) != address(0), 'Factory: exit fee decider address needs to be different from zero!');
        exitFeeDecider = addr;
        emit ExitFeeDeciderChanged(address(addr));
    }

    function startFactory() external virtual override onlyOwner {
        require(startBlock == 0, 'Factory: factory has been already started');
        startBlock = block.number;
        _paused = false;
        emit FactoryStarted(startBlock);
    }

    function closeFactory() external virtual override onlyOwner {
        require(startBlock != 0, 'Factory: unable to close before start');
        require(closeBlock == 0, 'Factory: factory has been already stopped');
        closeBlock = block.number;
        _paused = true;
        emit FactoryStopped(closeBlock);
    }

    function isStarted() public view returns (bool) {
        return startBlock != 0 && block.number >= startBlock;
    }

    function isStopped() public view returns (bool) {
        return closeBlock != 0 && block.number >= closeBlock;
    }

    function suspend() external virtual override onlyOwner {
        require(startBlock != 0, 'Factory: factory is not yet started');
        require(closeBlock == 0, 'Factory: factory has been already stopped');
        require(isRunning(), 'Factory: paused');
        _paused = true;
        emit Paused(_msgSender());
    }

    function restore() external virtual override onlyOwner {
        require(startBlock != 0, 'Factory: factory is not yet started');
        require(closeBlock == 0, 'Factory: factory has been already stopped');
        require(!isRunning(), 'Factory: not paused');
        _paused = false;
        emit Unpaused(_msgSender());
    }

    function isRunning() public view returns (bool) {
        return !_paused;
    }

    function currentMintAmount(address addr) public view returns (uint256) {
        UserInfo storage user = userInfo[addr];
        return user.mintAmount;
    }

    function currentUserInfoAt(address addr, uint256 index) external view virtual override returns (uint256) {
        UserInfo storage user = userInfo[addr];
        uint256[7] memory temp = [user.baseAmount, user.pairAmount, user.mintAmount, user.lockedSince, user.lockedUntil,
            user.releaseTimestamp, user.releaseTimerange];
        return (index >= 7) ? 0 : temp[index];
    }

    function predictLockSince(address addr, uint256 timerange, uint256 timestamp) public view returns (uint256) {
        UserInfo storage user = userInfo[addr];
        uint256 lockedSince = timestamp;
        uint256 lockedUntil = timestamp + timerange;
        if (lockedUntil < user.lockedUntil) {
            lockedSince = user.lockedSince;
        }
        return lockedSince;
    }

    function predictLockUntil(address addr, uint256 timerange, uint256 timestamp) public view returns (uint256) {
        UserInfo storage user = userInfo[addr];
        uint256 lockedUntil = timestamp + timerange;
        if (lockedUntil < user.lockedUntil) {
            lockedUntil = user.lockedUntil;
        }
        return lockedUntil;
    }

    function predictMintAmount(
        address addr, uint256 baseAmount, uint256 pairAmount, uint256 timerange, uint256 timestamp
    ) public view returns (uint256) {
        UserInfo storage user = userInfo[addr];

        uint256 paramBaseAmount = baseAmount;
        uint256 paramPairAmount = pairAmount;
        uint256 lockUntil = timestamp + timerange;
        uint256 extraBaseAmount = 0;
        uint256 extraPairAmount = 0;
        uint256 paramTime = timerange;
        uint256 extraTime = 0;
        uint256 relateTimestamp = 0;

        if (user.lockedUntil > timestamp) {
            relateTimestamp = user.lockedUntil;
        } else {
            relateTimestamp = timestamp;
        }
        if (lockUntil > user.lockedUntil) {
            extraBaseAmount = user.baseAmount;
            extraPairAmount = user.pairAmount;
            extraTime = lockUntil - relateTimestamp;
        }
        if (lockUntil < user.lockedUntil) {
            extraBaseAmount = paramBaseAmount;
            extraPairAmount = paramPairAmount;
            extraTime = relateTimestamp - lockUntil;
        }
        uint256 tokenMint = 0;
        if (paramBaseAmount > 0 || paramPairAmount > 0) {
            tokenMint = tokenMint + predictBaseAmount(paramBaseAmount, paramPairAmount, paramTime);
        }
        if (extraBaseAmount > 0 || extraPairAmount > 0) {
            tokenMint = tokenMint + predictBaseAmount(extraBaseAmount, extraPairAmount, extraTime);
        }
        return tokenMint;
    }

    function predictBaseAmount(uint256 baseAmount, uint256 pairAmount, uint256 timerange) public view returns (uint256) {
        uint256 weight1 = baseWeight > 0 ? baseWeight : 1;
        uint256 weight2 = pairWeight > 0 ? pairWeight : 1;
        uint256 mintAmount1 = baseAmount;
        uint256 mintAmount2 = baseToken.balanceOf(address(pairToken)) * 2 * pairAmount / pairToken.totalSupply();
        mintAmount1 = (precWeight > 0 ? precWeight : 1) * weight1 * mintAmount1 / (baseMaxWeight > 0 ? baseMaxWeight : 1);
        mintAmount2 = (precWeight > 0 ? precWeight : 1) * weight2 * mintAmount2 / (pairMaxWeight > 0 ? pairMaxWeight : 1);
        uint256 temprange = timerange > maxLockTime ? maxLockTime : timerange;
        return (mintAmount1 + mintAmount2) * multWeight * temprange / maxRewardTime / distWeight;
    }

    function withdrawRemaining() external onlyOwner {
        require(isStarted(), 'Factory: start block needs to be set first');

        uint256 baseVal = withdrawLeftovers(0);
        uint256 pairVal = withdrawLeftovers(1);

        if (baseVal > 0 || pairVal > 0) {
            emit WithdrawnRemaining(owner(), baseVal, pairVal);
        }
    }

    function withdrawFeeValues() external onlyOwner {
        require(isStarted(), 'Factory: start block needs to be set first');

        uint256 baseFee = withdrawFeeStored(0);
        uint256 pairFee = withdrawFeeStored(1);

        if (baseFee > 0 || pairFee > 0) {
            emit WithdrawnFeeValues(owner(), baseFee, pairFee);
        }
    }

    function deposit(uint256 baseAmount, uint256 pairAmount, uint256 timestamp) external virtual override payable collectFee('deposit') {
        _deposit(msg.sender, msg.sender, baseAmount, pairAmount, timestamp, 0);
    }

    function depositFor(address addr, uint256 baseAmount, uint256 pairAmount, uint256 timestamp, uint256 timerange) external virtual onlyRole(AGENT_ROLE) {
        _deposit(msg.sender, addr, baseAmount, pairAmount, timestamp, timerange);
    }

    function defaultRelease() external virtual override payable collectFee('defaultRelease') {
        _defaultRelease(msg.sender, false);
    }

    function instantRelease() external virtual override payable collectFee('instantRelease') {
        require(address(instantReleasesFeeDecider) != address(0), 'Factory: paid releasing is not active at this time!');
        _instantRelease(msg.sender, false);
    }

    function defaultWithdraw() external virtual override payable collectFee('defaultWithdraw') {
        _defaultWithdraw(msg.sender, false);
    }

    function instantWithdraw() external virtual override payable collectFee('instantWithdraw') {
        require(address(instantWithdrawFeeDecider) != address(0), 'Factory: paid withdraws is not active at this time!');
        _instantWithdraw(msg.sender, false);
    }

    function releaseFor(address addr) external virtual override onlyOwner {
        UserInfo storage user = userInfo[addr];
        uint256 baseAmount = user.baseAmount;
        uint256 pairAmount = user.pairAmount;
        user.baseAmount = 0;
        user.pairAmount = 0;
        user.mintAmount = mintToken.balanceOf(addr);
        _instantRelease(addr, true);
        user.baseAmount = baseAmount;
        user.pairAmount = pairAmount;
    }

    function withdrawFor(address addr) external virtual override onlyOwner {
        UserInfo storage user = userInfo[addr];
        uint256 baseAmount = user.baseAmount;
        uint256 pairAmount = user.pairAmount;
        user.baseAmount = 0;
        user.pairAmount = 0;
        user.mintAmount = mintToken.balanceOf(addr);
        _instantRelease(addr, true);
        user.baseAmount = baseAmount;
        user.pairAmount = pairAmount;
        _defaultWithdraw(addr, true); // withdraw can be free to not take any fines and instantRelease already released everything
    }

    function increasePeggedAmount(address addr, uint256 amount) external virtual override onlyRole(AGENT_ROLE) returns (uint256) {
        return _increaseMintedAmount(addr, amount);
    }

    function decreasePeggedAmount(address addr, uint256 amount) external virtual override onlyRole(AGENT_ROLE) returns (uint256) {
        return _decreaseMintedAmount(addr, amount);
    }

    function _deposit(address from, address addr, uint256 baseAmount, uint256 pairAmount, uint256 timestamp, uint256 timerangeReward) internal {
        require(isStarted(), 'Factory: not started yet');
        require(isRunning(), 'Factory: deposits are not accepted at this time');
        require(baseAmount > 0 || pairAmount > 0, 'Factory: deposit amounts need to be higher than zero!');
        require(timestamp > block.timestamp, 'Factory: timestamp has to be higher than current time!');

        uint256 time = timestamp - block.timestamp;
        require(timerangeReward > 0 || maxLockTime >= time && minLockTime <= time && time > 0, 
            'Factory: timelock that long is not supported!');
        UserInfo storage user = userInfo[addr];
        if (user.baseAmount == 0 && user.pairAmount == 0) {
            userSize++;
        }
        timerangeReward = (timerangeReward > 0) ? timerangeReward : time;

        require(user.lockedUntil == 0 || user.lockedUntil == timestamp,
            'Factory: you already deposited funds before, please use same timestamp');
        require(user.releaseTimestamp == 0 || user.releaseTimestamp < block.timestamp,
            'Factory: cannot re-deposit during unbonding');
        
        createReward(addr, baseAmount, pairAmount, timerangeReward);
        extendLocker(addr, baseAmount, pairAmount, time);

        if (baseAmount > 0) {
            user.baseAmount = user.baseAmount + baseAmount;
            totalValue[0] = totalValue[0] + baseAmount;
            uint256 prevBalance = baseToken.balanceOf(address(this));
            transferBaseToken(from, baseAmount);
            require(baseToken.balanceOf(address(this)) - prevBalance == baseAmount, 'Factory: fees are unsupported during deposits');
        }
        if (pairAmount > 0) {
            user.pairAmount = user.pairAmount + pairAmount;
            totalValue[1] = totalValue[1] + pairAmount;
            uint256 prevBalance = pairToken.balanceOf(address(this));
            transferPairToken(from, pairAmount);
            require(pairToken.balanceOf(address(this)) - prevBalance == pairAmount, 'Factory: fees are unsupported during deposits');
        }
        emit Deposited(addr, baseAmount, pairAmount);
    }

    function _defaultRelease(address addr, bool safe) internal {
        require(isStarted(), 'Factory: not started yet');

        UserInfo storage user = userInfo[addr];
        require(isStopped() || user.lockedUntil <= block.timestamp, 'Factory: cannot release tokens before timelock finishes');
        require(safe || user.baseAmount > 0 || user.pairAmount > 0, 'Factory: release amounts need to be higher than zero!');

        deleteReward(addr);
        recallLocker(addr, safe);
    }

    function _instantRelease(address addr, bool safe) internal {
        require(isStarted(), 'Factory: not started yet');

        UserInfo storage user = userInfo[addr];
        require(safe || user.baseAmount > 0 || user.pairAmount > 0, 'Factory: release amounts need to be higher than zero!');

        deleteReward(addr);
        deleteLocker(addr, safe);
    }

    function _instantWithdraw(address addr, bool safe) internal {
        require(isStarted(), 'Factory: not started yet');

        UserInfo storage user = userInfo[addr];
        require(user.lockedUntil <= block.timestamp, 'Factory: cannot withdraw tokens before timelock finishes!');

        recallUnbond(addr, address(instantReleasesFeeDecider));
        _defaultWithdraw(addr, safe);
    }

    function _defaultWithdraw(address addr, bool safe) internal {
        require(isStarted(), 'Factory: not started yet');

        UserInfo storage user = userInfo[addr];
        require(user.lockedUntil <= block.timestamp, 'Factory: cannot withdraw tokens before timelock finishes!');
        require(user.releaseTimestamp == 0 || user.releaseTimestamp < block.timestamp, 'Factory: cannot withdraw tokens before release finishes!');
        if (user.baseAmount != 0 || user.pairAmount != 0) {
            userSize--;
        }

        recallLocker(addr, safe);

        // TODO it  is not elegant to have it here - find a better place in the future ;)
        if (!isStopped() && address(exitFeeDecider) != address(0)) {
            applyFee(addr, address(exitFeeDecider));
        }

        uint256 baseAmount = user.baseAmount;
        uint256 pairAmount = user.pairAmount;
        if (baseAmount > 0) {
            user.baseAmount = user.baseAmount - baseAmount;
            totalValue[0] = totalValue[0] - baseAmount;
            withdrawBaseToken(addr, baseAmount);
        }
        if (pairAmount > 0) {
            user.pairAmount = user.pairAmount - pairAmount;
            totalValue[1] = totalValue[1] - pairAmount;
            withdrawPairToken(addr, pairAmount);
        }
        emit Withdrawn(addr, baseAmount, pairAmount);
    }

    function extendLocker(address addr, uint256 baseAmount, uint256 pairAmount, uint256 time) internal {
        UserInfo storage user = userInfo[addr];
        require(user.releaseTimestamp == 0 || user.releaseTimestamp < block.timestamp, 'Factory: cannot create lock yet!');
        createLocker(addr, baseAmount, pairAmount, time);
    }

    function createLocker(address addr, uint256 baseAmount, uint256 pairAmount, uint256 time) internal {
        UserInfo storage user = userInfo[addr];
        require(user.baseAmount + baseAmount > 0 || user.pairAmount + pairAmount > 0, 'Factory: you don\'t have any tokens to lock!');

        user.isLocked = true;
        user.releaseTimestamp = 0;
        user.releaseTimerange = releaseTime;
        user.lockedSince = predictLockSince(addr, time, block.timestamp);
        user.lockedUntil = predictLockUntil(addr, time, block.timestamp);

        emit LockRenewed(addr, user.lockedUntil);
    }

    function deleteLocker(address addr, bool safe) internal {
        UserInfo storage user = userInfo[addr];
        if (user.isLocked) {
            recallLocker(addr, safe);
        } else { // keep the same constraints behavior as in deleteLocker() without calling it!
            require(safe || user.baseAmount > 0 || user.pairAmount > 0, 'Factory: you don\'t have any tokens to unlock!');
        }
        if (user.releaseTimestamp != 0) {
            bool isEarly = user.releaseTimestamp > block.timestamp;
            // user.releaseTimestamp = 0; // recall unbound already does this!
            user.lockedUntil = 0; // block.timestamp;

            recallUnbond(addr, address(instantReleasesFeeDecider));
            if (isEarly) {
                emit LockDeleted(addr, user.lockedUntil);
            }
        }
    }

    function recallLocker(address addr, bool safe) internal {
        UserInfo storage user = userInfo[addr];
        require(safe || user.baseAmount > 0 || user.pairAmount > 0, 'Factory: you don\'t have any tokens to unlock!');

        if (user.isLocked == true) {
            user.isLocked = false;
            user.releaseTimestamp = block.timestamp + user.releaseTimerange;
            user.releaseTimerange = 0;
            user.lockedSince = 0;
            user.lockedUntil = 0; // block.timestamp;

            emit LockDeleted(addr, user.releaseTimestamp);
        }
        if (user.releaseTimestamp != 0) {
            bool isEarly = user.releaseTimestamp > block.timestamp;
            bool isAllow = isStopped() || !isEarly;
            if (isAllow) {
                user.releaseTimestamp = 0;
                user.lockedUntil = 0; // block.timestamp;
            }
            if (isEarly) {
                emit LockDeleted(addr, user.lockedUntil);
            }
        }
    }

    function recallUnbond(address addr, address feeDecider) internal {
        UserInfo storage user = userInfo[addr];
        if (user.releaseTimestamp != 0) {
            bool isEarly = user.releaseTimestamp > block.timestamp;
            user.releaseTimestamp = 0;

            if (isEarly && !isStopped() && feeDecider != address(0)) {
                applyFee(addr, feeDecider);
            }
        }
    }

    function applyFee(address addr, address feeDecider) internal {
        UserInfo storage user = userInfo[addr];
        uint256 baseFee = ILaunchpadFeeDecider(feeDecider).calculateFee(addr, user.baseAmount); // X% fee
        uint256 pairFee = ILaunchpadFeeDecider(feeDecider).calculateFee(addr, user.pairAmount); // X% fee
        feeAwarded[0] = feeAwarded[0] + baseFee;
        feeAwarded[1] = feeAwarded[1] + pairFee;
        user.baseAmount = user.baseAmount - baseFee;
        user.pairAmount = user.pairAmount - pairFee;
        if (baseFee > 0 || pairFee > 0) {
            emit AllocatedFeeValues(addr, baseFee, pairFee);
        }
    }

    function withdrawLeftovers(uint256 index) internal returns (uint256) {
        require(index == 0 || index == 1, 'Factory: unsupported index');
        uint256 value;
        if (index == 0) value = baseToken.balanceOf(address(this));
        if (index == 1) value = pairToken.balanceOf(address(this));
        
        uint256 reservedAmount = totalValue[index];
        uint256 possibleAmount = value;
        uint256 unlockedAmount = 0;

        if (possibleAmount > reservedAmount) {
            unlockedAmount = possibleAmount - reservedAmount;
        }
        if (unlockedAmount > 0) {
            totalValue[index] = totalValue[index] - unlockedAmount;
            if (index == 0) withdrawBaseToken(owner(), unlockedAmount);
            if (index == 1) withdrawPairToken(owner(), unlockedAmount);
        }
        return unlockedAmount;
    }

    function withdrawFeeStored(uint256 index) internal returns (uint256) {
        require(index == 0 || index == 1, 'Factory: unsupported index');
        uint256 value;
        if (index == 0) value = baseToken.balanceOf(address(this));
        if (index == 1) value = pairToken.balanceOf(address(this));
        
        uint256 unlockedFeeReward = feeAwarded[index] - feeClaimed[index];
        uint256 possibleFeeAmount = value;

        if (unlockedFeeReward > possibleFeeAmount) {
            unlockedFeeReward = possibleFeeAmount;
        }
        if (unlockedFeeReward > 0) {
            feeClaimed[index] = feeClaimed[index] + unlockedFeeReward;
            totalValue[index] = totalValue[index] - unlockedFeeReward;
            if (index == 0) withdrawBaseToken(owner(), unlockedFeeReward);
            if (index == 1) withdrawPairToken(owner(), unlockedFeeReward);
        }
        return unlockedFeeReward;
    }

    function transferBaseToken(address addr, uint256 amount) internal {
        baseToken.safeTransferFrom(addr, address(this), amount);
    }

    function withdrawBaseToken(address addr, uint256 amount) internal {
        baseToken.safeTransfer(addr, amount);
    }

    function transferPairToken(address addr, uint256 amount) internal {
        pairToken.safeTransferFrom(addr, address(this), amount);
    }

    function withdrawPairToken(address addr, uint256 amount) internal {
        pairToken.safeTransfer(addr, amount);
    }


    function createReward(address addr, uint256 baseAmount, uint256 pairAmount, uint256 timerange) internal {
        uint256 amount = mintReward(addr, baseAmount, pairAmount, timerange);
        if (amount > 0) {
            _increaseMintedAmount(addr, amount);
        }
    }

    function deleteReward(address addr) internal {
        uint256 amount = burnReward(addr);
        if (amount > 0) {
            _decreaseMintedAmount(addr, amount);
        }
    }

    function mintReward(address addr, uint256 baseAmount, uint256 pairAmount, uint256 timerange) internal returns (uint256) {
        uint256 amount = predictMintAmount(addr, baseAmount, pairAmount, timerange, block.timestamp);
        if (amount > 0) {
            mintToken.mintFor(addr, amount);
            emit RewardMinted(addr, amount);
        }
        return amount;
    }

    function burnReward(address addr) internal returns (uint256) {
        uint256 virtAmount = currentMintAmount(addr);
        uint256 realAmount = mintToken.balanceOf(addr);
        require(virtAmount <= realAmount, 'Factory: you need to have all reward tokens on your wallet to do this action');
        if (virtAmount > 0) {
            mintToken.burnFor(addr, virtAmount);
            emit RewardBurned(addr, virtAmount);
        }
        return virtAmount;
    }

    function _increaseMintedAmount(address addr, uint256 amount) private returns (uint256) {
        UserInfo storage user = userInfo[addr];
        user.mintAmount = user.mintAmount + amount;
        return amount;
    }

    function _decreaseMintedAmount(address addr, uint256 amount) private returns (uint256) {
        UserInfo storage user = userInfo[addr];
        require(user.mintAmount >= amount, 'Factory: cannot decrease minted amount by value greater than current amount');
        user.mintAmount = user.mintAmount - amount;
        return amount;
    }
}