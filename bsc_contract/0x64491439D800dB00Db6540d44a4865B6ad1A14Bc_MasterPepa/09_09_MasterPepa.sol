// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @notice Pepa Inu's MasterPepa learned from Pancakeswap's MasterChefV2.
///
/// MasterPepa has been adjusted for depositable reward tokens instead 
/// of minting ones. PEPA has to be deposited by calling addPepaRewards, which
/// transfers PEPA tokens into the contract and sets the emission rate.
///
/// All pools are regular as there is no need for special pools.
/// Burn method was removed.
contract MasterPepa is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Info of each MasterPepa user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards. See explanation below.
    ///
    /// We do some fancy math here. Basically, any point in time, the amount of PEPAs
    /// entitled to a user but is pending to be distributed is:
    ///
    ///   pending reward = (user share * pool.accPepaPerShare) - user.rewardDebt
    ///
    ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    ///   1. The pool's `accPepaPerShare` (and `lastRewardBlock`) gets updated.
    ///   2. User receives the pending reward sent to his/her address.
    ///   3. User's `amount` gets updated. Pool's `totalBoostedShare` gets updated.
    ///   4. User's `rewardDebt` gets updated.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 boostMultiplier;
    }

    /// @notice Info of each MasterPepa pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    ///     Also known as the amount of "multipliers". Combined with `totalAllocPoint`, it defines the % of
    ///     PEPA rewards each pool gets.
    /// `accPepaPerShare` Accumulated PEPAs per share, times 1e12.
    /// `lastRewardBlock` Last block number that pool update action is executed.
    /// `totalBoostedShare` The total amount of user shares in each pool. After considering the share boosts.
    struct PoolInfo {
        uint256 accPepaPerShare;
        uint256 lastRewardBlock;
        uint256 allocPoint;
        uint256 totalBoostedShare;
    }

    /// @notice Address of PEPA contract.
    IERC20 public immutable PEPA;

    /// @notice The contract handles the share boosts.
    address public boostContract;

    /// @notice Info of each MasterPepa pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each MasterPepa pool.
    IERC20[] public lpToken;

    /// @notice Info of each pool user.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// @notice Total allocation points. Must be the sum of all pools' allocation points.
    uint256 public totalAllocPoint;

    /// @notice Total amount of PEPA deposited for emission.
    uint256 public totalPepaSupplied = 0;
    /// @notice Total amount of PEPA accumulated as emission.
    uint256 public totalPepaAllocated = 0;
    /// @notice Amount of PEPA emitted each block until lastEmittingBlock
    uint256 public pepaPerBlock = 0 * 1e18;
    /// @notice Precision for reward math calculations in accPepaPerShare and rewardDept
    uint256 public constant ACC_PEPA_PRECISION = 1e18;

    /// @notice Basic boost factor, none boosted user's boost factor
    uint256 public constant BOOST_PRECISION = 100 * 1e10;
    /// @notice Hard limit for maxmium boost factor, it must greater than BOOST_PRECISION
    uint256 public constant MAX_BOOST_PRECISION = 200 * 1e10;

    /// @notice Block number until which current rewards will last at current emision.
    uint256 public lastEmittingBlock;

    event AddPool(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
    event SetPool(uint256 indexed pid, uint256 allocPoint);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accPepaPerShare);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdrawReward(address indexed operator, address receiver, uint256 amount);

    event UpdatePepaEmission(uint256 pepaPerBlock, uint256 lastEmittingBlock);
    event UpdateBurnAdmin(address indexed oldAdmin, address indexed newAdmin);
    event UpdateWhiteList(address indexed user, bool isValid);
    event UpdateBoostContract(address indexed boostContract);
    event UpdateBoostMultiplier(address indexed user, uint256 pid, uint256 oldMultiplier, uint256 newMultiplier);

    /// @param _PEPA The PEPA token contract address.
    constructor(
        IERC20 _PEPA
    ) {
        PEPA = _PEPA;
    }

    /**
     * @dev Throws if caller is not the boost contract.
     */
    modifier onlyBoostContract() {
        require(boostContract == msg.sender, "Ownable: caller is not the boost contract");
        _;
    }

    /// @notice Returns the number of MasterPepa pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param _allocPoint Number of allocation points for the new pool.
    /// @param _lpToken Address of the LP BEP-20 token.
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) external onlyOwner {
        require(_lpToken.balanceOf(address(this)) >= 0, "None BEP20 tokens");
        // stake PEPA token will cause staked token and reward token mixed up,
        // may cause staked tokens withdraw as reward token,never do it.
        require(_lpToken != PEPA, "PEPA token can't be added to farm pools");

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        lpToken.push(_lpToken);

        poolInfo.push(
            PoolInfo({
                allocPoint: _allocPoint,
                lastRewardBlock: block.number,
                accPepaPerShare: 0,
                totalBoostedShare: 0
            })
        );
        emit AddPool(lpToken.length.sub(1), _allocPoint, _lpToken);
    }

    /// @notice Update the given pool's PEPA allocation point. Can only be called by the owner.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _allocPoint New number of allocation points for the pool.
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        // No matter _withUpdate is true or false, we need to execute updatePool once before set the pool parameters.
        updatePool(_pid);

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(_pid, _allocPoint);
    }

    /// @notice View function for checking pending PEPA rewards.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _user Address of the user.
    function pendingPepa(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accPepaPerShare = pool.accPepaPerShare;
        uint256 lpSupply = pool.totalBoostedShare;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock);

            uint256 pepaReward = multiplier.mul(pepaPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
            pepaReward = safeAllocatablePepa(pepaReward);
            accPepaPerShare = accPepaPerShare.add(pepaReward.mul(ACC_PEPA_PRECISION).div(lpSupply));
        }

        uint256 boostedAmount = user.amount.mul(getBoostMultiplier(_user, _pid)).div(BOOST_PRECISION);
        return boostedAmount.mul(accPepaPerShare).div(ACC_PEPA_PRECISION).sub(user.rewardDebt);
    }

    /// @notice Update pepa reward for all the active pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfo[pid];
            if (pool.allocPoint != 0) {
                updatePool(pid);
            }
        }
    }

    /// @notice Update reward variables for the given pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[_pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalBoostedShare;

            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 multiplier = getMultiplier(pool.lastRewardBlock);
                uint256 pepaReward = multiplier.mul(pepaPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
                pepaReward = safeAllocatePepa(pepaReward);
                pool.accPepaPerShare = pool.accPepaPerShare.add((pepaReward.mul(ACC_PEPA_PRECISION).div(lpSupply)));
            }
            pool.lastRewardBlock = block.number;
            poolInfo[_pid] = pool;
            emit UpdatePool(_pid, pool.lastRewardBlock, lpSupply, pool.accPepaPerShare);
        }
    }

    /// @notice Deposit LP tokens to pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _amount Amount of LP tokens to deposit.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);

        if (user.amount > 0) {
            settlePendingPepa(msg.sender, _pid, multiplier);
        }

        if (_amount > 0) {
            uint256 before = lpToken[_pid].balanceOf(address(this));
            lpToken[_pid].safeTransferFrom(msg.sender, address(this), _amount);
            _amount = lpToken[_pid].balanceOf(address(this)).sub(before);
            user.amount = user.amount.add(_amount);

            // Update total boosted share.
            pool.totalBoostedShare = pool.totalBoostedShare.add(_amount.mul(multiplier).div(BOOST_PRECISION));
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(pool.accPepaPerShare).div(
            ACC_PEPA_PRECISION
        );
        poolInfo[_pid] = pool;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _amount Amount of LP tokens to withdraw.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: Insufficient");

        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);

        settlePendingPepa(msg.sender, _pid, multiplier);

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            lpToken[_pid].safeTransfer(msg.sender, _amount);
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(pool.accPepaPerShare).div(
            ACC_PEPA_PRECISION
        );
        poolInfo[_pid].totalBoostedShare = poolInfo[_pid].totalBoostedShare.sub(
            _amount.mul(multiplier).div(BOOST_PRECISION)
        );

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw without caring about the rewards. EMERGENCY ONLY.
    /// @param _pid The id of the pool. See `poolInfo`.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        uint256 boostedAmount = amount.mul(getBoostMultiplier(msg.sender, _pid)).div(BOOST_PRECISION);
        pool.totalBoostedShare = pool.totalBoostedShare > boostedAmount ? pool.totalBoostedShare.sub(boostedAmount) : 0;

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[_pid].safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }
     
    /// @notice Update PEPA reward emission rate.
    /// @param _pepaPerBlock The total PEPA emission each block.
    function updatePepaEmission(
        uint256 _pepaPerBlock
    ) external onlyOwner {
        massUpdatePools();

        pepaPerBlock = _pepaPerBlock;
        if (_pepaPerBlock == 0) {
            lastEmittingBlock = block.number;
        } else {
            lastEmittingBlock =  block.number.add(
                // div round up
                (allocatablePepa().add(_pepaPerBlock.sub(1))).div(_pepaPerBlock)
            );
        }

        emit UpdatePepaEmission(_pepaPerBlock, lastEmittingBlock);
    }

    /// @notice Deposit PEPA rewards for emission.
    /// @param _amount The total PEPA to add for emission.
    function addPepaRewards(
        uint256 _amount
    ) external {
        require(_amount > 0, "Invalid amount");
        massUpdatePools();

        uint256 balance = PEPA.balanceOf(address(this));
        PEPA.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 deposited = PEPA.balanceOf(address(this)) - balance;
        require(deposited > 0, "Amount too low");
        
        totalPepaSupplied = totalPepaSupplied.add(deposited);

        if (pepaPerBlock == 0) {
            lastEmittingBlock = block.number;
        } else {
            lastEmittingBlock =  block.number.add(
                // div round up
                (allocatablePepa().add(pepaPerBlock.sub(1))).div(pepaPerBlock)
            );
        }

        emit UpdatePepaEmission(pepaPerBlock, lastEmittingBlock);
    }

    /// @notice Withdraw without caring about the rewards. EMERGENCY ONLY.
    /// @dev Only withdraws PEPA which is not allocated already for rewards.
    /// @param _receiver Receiver of PEPA.
    function emergencyWithdrawPepaRewards(address _receiver) external onlyOwner {
        massUpdatePools();
        pepaPerBlock = 0;
        lastEmittingBlock = block.number;
        emit UpdatePepaEmission(pepaPerBlock, lastEmittingBlock);

        uint256 available = safeAllocatePepa(type(uint256).max);
        safeTransferPepa(_receiver, available);
        emit EmergencyWithdrawReward(msg.sender, _receiver, available);
    }

    /// @notice Update boost contract address and max boost factor.
    /// @param _newBoostContract The new address for handling all the share boosts.
    function updateBoostContract(address _newBoostContract) external onlyOwner {
        require(
            _newBoostContract != address(0) && _newBoostContract != boostContract,
            "MasterPepa: New boost contract address must be valid"
        );

        boostContract = _newBoostContract;
        emit UpdateBoostContract(_newBoostContract);
    }

    /// @notice Update user boost factor.
    /// @param _user The user address for boost factor updates.
    /// @param _pid The pool id for the boost factor updates.
    /// @param _newMultiplier New boost multiplier.
    function updateBoostMultiplier(
        address _user,
        uint256 _pid,
        uint256 _newMultiplier
    ) external onlyBoostContract nonReentrant {
        require(_user != address(0), "MasterPepa: The user address must be valid");
        require(
            _newMultiplier >= BOOST_PRECISION && _newMultiplier <= MAX_BOOST_PRECISION,
            "MasterPepa: Invalid new boost multiplier"
        );

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];

        uint256 prevMultiplier = getBoostMultiplier(_user, _pid);
        settlePendingPepa(_user, _pid, prevMultiplier);

        user.rewardDebt = user.amount.mul(_newMultiplier).div(BOOST_PRECISION).mul(pool.accPepaPerShare).div(
            ACC_PEPA_PRECISION
        );
        pool.totalBoostedShare = pool.totalBoostedShare.sub(user.amount.mul(prevMultiplier).div(BOOST_PRECISION)).add(
            user.amount.mul(_newMultiplier).div(BOOST_PRECISION)
        );
        poolInfo[_pid] = pool;
        userInfo[_pid][_user].boostMultiplier = _newMultiplier;

        emit UpdateBoostMultiplier(_user, _pid, prevMultiplier, _newMultiplier);
    }

    /// @notice Get user boost multiplier for specific pool id.
    /// @param _user The user address.
    /// @param _pid The pool id.
    function getBoostMultiplier(address _user, uint256 _pid) public view returns (uint256) {
        uint256 multiplier = userInfo[_pid][_user].boostMultiplier;
        return multiplier > BOOST_PRECISION ? multiplier : BOOST_PRECISION;
    }

    /// @notice Settles, distribute the pending PEPA rewards for given user.
    /// @param _user The user address for settling rewards.
    /// @param _pid The pool id.
    /// @param _boostMultiplier The user boost multiplier in specific pool id.
    function settlePendingPepa(
        address _user,
        uint256 _pid,
        uint256 _boostMultiplier
    ) internal {
        UserInfo memory user = userInfo[_pid][_user];

        uint256 boostedAmount = user.amount.mul(_boostMultiplier).div(BOOST_PRECISION);
        uint256 accPepa = boostedAmount.mul(poolInfo[_pid].accPepaPerShare).div(ACC_PEPA_PRECISION);
        uint256 pending = accPepa.sub(user.rewardDebt);
        // SafeTransfer PEPA
        safeTransferPepa(_user, pending);
    }

    /// @notice Safe Transfer PEPA.
    /// @param _to The PEPA receiver address.
    /// @param _amount transfer PEPA amounts.
    function safeTransferPepa(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            uint256 balance = PEPA.balanceOf(address(this));
            if (balance < _amount) {
                _amount = balance;
            }
            PEPA.safeTransfer(_to, _amount);
        }
    }

    /// @notice PEPA which was supplied and is not emitteallocated yet.
    function allocatablePepa() public view returns (uint256) {
        return totalPepaSupplied - totalPepaAllocated;
    }

    /// @notice _amount capped by allocatablePepa().
    function safeAllocatablePepa(uint256 _amount) internal view returns (uint256) {
        uint256 available = allocatablePepa();
        if (available < _amount) {
            _amount = available;
        }
        return _amount;
    }

    /// @notice book _amount as allocated PEPA which can not be withdrawn from contract.
    function safeAllocatePepa(uint256 _amount) internal returns (uint256 allocated) {
        allocated = safeAllocatablePepa(_amount);
        totalPepaAllocated = totalPepaAllocated.add(allocated);
    }

    /// @notice Returns the number of blocks since _lastRewardBlock which had rewards emitted.
    function getMultiplier(uint256 _lastRewardBlock) internal view returns (uint256) {
        uint256 toBlock = (block.number > lastEmittingBlock) ? lastEmittingBlock : block.number;
        return toBlock >= _lastRewardBlock ? toBlock.sub(_lastRewardBlock) : 0;
    }
}