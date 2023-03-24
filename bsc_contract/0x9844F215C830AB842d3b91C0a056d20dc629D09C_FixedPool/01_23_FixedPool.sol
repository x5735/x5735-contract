// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./FixedPoolReserve.sol";
import "./Nft.sol";

contract FixedPool is AccessControl {
    using SafeMath for uint256;

    struct Config {
        IERC20 token;
        FixedPoolReserve reserve;
        bool depositDisabled;
        uint256 maxNftStaked;
        uint256 maxActiveOrders;
    }

    Config public config;

    struct PoolInfo {
        uint256 apr;
        uint256 duration;

        uint256 total;
    }

    PoolInfo[] public pools;

    struct OrderInfo {
        uint256 poolPid;
        uint256 apr;

        uint256 totalStaked;

        uint256 totalAccumulation;
        uint256 accumulationAt;

        uint256 createdAt;
        uint256 unlockAt;
    }

    mapping(address => OrderInfo[]) private orders;

    struct CanceledOrderInfo {
        uint256 apr;

        uint256 totalStaked;
        uint256 totalRewards;

        uint256 createdAt;
        uint256 unlockAt;
        uint256 canceledAt;
    }

    mapping(address => CanceledOrderInfo[]) private canceledOrders;

    struct NftInfo {
        address nftAddress;
        uint256 nftId;
    }

    mapping(address => NftInfo[]) public usersNft;

    mapping(address => bool) public availableNfts;

    event PoolAddedEvent(uint256 indexed _pid, uint256 _apr, uint256 _duration);
    event PoolUpdatedEvent(uint256 indexed _pid, uint256 _apr, uint256 _duration);

    event DepositDisableEvent();
    event DepositEnableEvent();

    event MaxNftStakedUpdateEvent(uint256 _maxNftStaked);
    event MaxActiveOrdersUpdateEvent(uint256 _maxActiveOrders);

    event UserNftStakeEvent(address indexed _user, address indexed _nftAddres, uint256 _nftId);
    event UserNftUnstakeEvent(address indexed _user, address indexed _nftAddres, uint256 _nftId);

    event DepositEvent(address indexed _user, uint256 indexed _poolPid, uint256 _totalStaked);
    event WithdrawEvent(address indexed _user, uint256 _canceledOrderPid, uint256 _totalStaked, uint256 _totalRewards);
    event EmergencyWithdrawEvent(address indexed _user, uint256 _canceledOrderPid, uint256 _totalStaked);

    event AvailableNftUpdateEvent(address indexed _nftAddress, bool _available);

    constructor(IERC20 _token) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        config.reserve = new FixedPoolReserve();

        config.token = _token;
    }

    function poolLength() public view returns (uint256) {
        return pools.length;
    }

    function orderLength(address _user) public view returns (uint256) {
        return orders[_user].length;
    }

    function canceledOrderLength(address _user) public view returns (uint256) {
        return canceledOrders[_user].length;
    }

    function orderInfo(address _user, uint256 _orderPid) public view returns (
        uint256 apr,
        uint256 totalStaked,
        uint256 totalEarned,
        uint256 newEarned,
        uint256 totalAccumulation,
        uint256 accumulationAt,
        uint256 createdAt,
        uint256 unlockAt
    ) {
        OrderInfo storage order = orders[_user][_orderPid];

        uint256 currentTime = block.timestamp;
        if (currentTime > order.unlockAt) {
            currentTime = order.unlockAt;
        }

        uint256 timePassed = currentTime.sub(order.accumulationAt);

        apr = order.apr;
        totalStaked = order.totalStaked;
        totalAccumulation = order.totalAccumulation;
        accumulationAt = order.accumulationAt;
        uint256 calculatedApr = order.apr;
        uint256 userApr = userBoostApr(_user);
        if (userApr > 0) {
            calculatedApr = calculatedApr.mul(userApr.add(10000)).div(10000);
        }
        newEarned = order.totalStaked.mul(calculatedApr).div(10000).mul(timePassed).div(365 days);
        totalEarned = totalAccumulation.add(newEarned);
        createdAt = order.createdAt;
        unlockAt = order.unlockAt;
    }

    function canceledOrderInfo(address _user, uint256 _orderPid) public view returns (
        uint256 apr,
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 createdAt,
        uint256 unlockAt,
        uint256 canceledAt
    ) {
        CanceledOrderInfo storage canceledOrder = canceledOrders[_user][_orderPid];

        apr = canceledOrder.apr;
        totalStaked = canceledOrder.totalStaked;
        totalRewards = canceledOrder.totalRewards;
        createdAt = canceledOrder.createdAt;
        unlockAt = canceledOrder.unlockAt;
        canceledAt = canceledOrder.canceledAt;
    }

    function usersNftLength(address _user) external view returns (uint256){
        return usersNft[_user].length;
    }

    function userBoostApr(address _user) public view returns (uint256){
        uint256 apr = 0;

        for (uint256 i = 0; i < usersNft[_user].length; i++) {
            apr = apr.add(Nft(usersNft[_user][i].nftAddress).getAprByTokenId(usersNft[_user][i].nftId));
        }

        return apr;
    }

    function deposit(uint256 _poolPid, uint256 _amount) external {
        require(!config.depositDisabled, "deposit disabled");
        require(orders[msg.sender].length < config.maxActiveOrders, "you have reached the maximum number of orders");

        PoolInfo storage pool = pools[_poolPid];
        require(pool.apr > 0, "pool not active");

        uint256 oldBalance = config.token.balanceOf(address(config.reserve));
        config.token.transferFrom(msg.sender, address(config.reserve), _amount);
        uint256 newBalance = config.token.balanceOf(address(config.reserve));

        _amount = newBalance.sub(oldBalance);

        pool.total = pool.total.add(_amount);

        uint256 createdAt = block.timestamp;
        OrderInfo memory order;
        order.poolPid = _poolPid;
        order.apr = pool.apr;
        order.totalStaked = _amount;
        order.totalAccumulation = 0;
        order.accumulationAt = createdAt;
        order.createdAt = createdAt;
        order.unlockAt = createdAt.add(pool.duration);

        orders[msg.sender].push(order);

        emit DepositEvent(
            msg.sender,
            _poolPid,
            _amount
        );
    }

    function withdraw(uint256 _orderPid) external {
        OrderInfo memory order = orders[msg.sender][_orderPid];

        require(order.unlockAt <= block.timestamp, "order is not completed");

        updateOrder(msg.sender, _orderPid);

        require(config.token.balanceOf(address(this)) >= order.totalAccumulation, "insufficient reserves to pay the award");

        config.reserve.recoverTokensFor(address(config.token), order.totalStaked, msg.sender);

        config.token.transfer(msg.sender, order.totalAccumulation);

        // delete order
        for (uint256 i = _orderPid; i < orders[msg.sender].length - 1; i++) {
            orders[msg.sender][i] = orders[msg.sender][i + 1];
        }
        orders[msg.sender].pop();

        // create canceled order
        CanceledOrderInfo memory canceledOrder = CanceledOrderInfo({
        apr : order.apr,

        totalStaked : order.totalStaked,
        totalRewards : order.totalAccumulation,

        createdAt : order.createdAt,
        unlockAt : order.unlockAt,
        canceledAt : block.timestamp
        });

        canceledOrders[msg.sender].push(canceledOrder);

        emit WithdrawEvent(
            msg.sender,
            canceledOrderLength(msg.sender) - 1,
            canceledOrder.totalStaked,
            canceledOrder.totalRewards
        );
    }

    function emergencyWithdraw(uint256 _orderPid) external {
        OrderInfo memory order = orders[msg.sender][_orderPid];

        config.reserve.recoverTokensFor(address(config.token), order.totalStaked, msg.sender);

        // delete order
        for (uint256 i = _orderPid; i < orders[msg.sender].length - 1; i++) {
            orders[msg.sender][i] = orders[msg.sender][i + 1];
        }
        orders[msg.sender].pop();

        // create canceled order
        CanceledOrderInfo memory canceledOrder = CanceledOrderInfo({
        apr : order.apr,

        totalStaked : order.totalStaked,
        totalRewards : 0,

        createdAt : order.createdAt,
        unlockAt : order.unlockAt,
        canceledAt : block.timestamp
        });

        canceledOrders[msg.sender].push(canceledOrder);

        emit EmergencyWithdrawEvent(
            msg.sender,
            canceledOrderLength(msg.sender) - 1,
            canceledOrder.totalStaked
        );
    }

    function stakeNft(address _nftAddress, uint256 _nftId) external {
        updateOrders();

        require(availableNfts[_nftAddress], "nft is not in the whitelist");

        require(usersNft[msg.sender].length < config.maxNftStaked, "you have staked the maximum number of nfts");

        (bool exists, bool isBurned, address owner, ,uint256 kind, , ,) = Nft(_nftAddress).nftInfoOf(_nftId);

        require(exists, "nft does not exist");
        require(!isBurned, "nft burned");
        require(owner == msg.sender, "you are not the owner of nft");

        for (uint256 i = 0; i < usersNft[msg.sender].length; i++) {
            if (usersNft[msg.sender][i].nftAddress == _nftAddress) {
                (, , , uint256 localKind, , , ,) = Nft(_nftAddress).nftInfoOf(usersNft[msg.sender][i].nftId);
                require(kind != localKind, "this kind of nft is already staked");
            }
        }

        Nft(_nftAddress).transferFrom(msg.sender, address(this), _nftId);

        usersNft[msg.sender].push(NftInfo(_nftAddress, _nftId));

        emit UserNftStakeEvent(msg.sender, _nftAddress, _nftId);
    }

    function unstakeNft(uint256 _nftIndex) external {
        updateOrders();

        NftInfo memory nft = usersNft[msg.sender][_nftIndex];

        Nft(nft.nftAddress).transferFrom(address(this), msg.sender, nft.nftId);

        // delete order
        for (uint256 i = _nftIndex; i < usersNft[msg.sender].length - 1; i++) {
            usersNft[msg.sender][i] = usersNft[msg.sender][i + 1];
        }
        usersNft[msg.sender].pop();

        emit UserNftUnstakeEvent(msg.sender, nft.nftAddress, nft.nftId);
    }

    function updateOrders() public {
        for (uint256 i = 0; i < orders[msg.sender].length; i++) {
            updateOrder(msg.sender, i);
        }
    }

    function updateOrders(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < orders[_user].length; i++) {
            updateOrder(_user, i);
        }
    }

    function updateOrder(address _user, uint256 _orderPid) public {
        OrderInfo storage order = orders[_user][_orderPid];

        uint256 currentTime = block.timestamp;
        if (currentTime > order.unlockAt) {
            currentTime = order.unlockAt;
        }

        uint256 timePassed = currentTime.sub(order.accumulationAt);

        if (timePassed > 0) {
            uint256 apr = order.apr;
            uint256 userApr = userBoostApr(_user);
            if (userApr > 0) {
                apr = apr.mul(userApr.add(10000)).div(10000);
            }
            uint256 newRewards = order.totalStaked.mul(apr).div(10000).mul(timePassed).div(365 days);
            order.totalAccumulation = order.totalAccumulation.add(newRewards);
            order.accumulationAt = currentTime;
        }
    }

    function disableDeposit() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!config.depositDisabled, "deposit disabled");

        config.depositDisabled = true;

        emit DepositDisableEvent();
    }

    function enableDeposit() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(config.depositDisabled, "deposit enabled");

        config.depositDisabled = false;

        emit DepositEnableEvent();
    }

    function setMaxNftStaked(uint256 _maxNftStaked) public onlyRole(DEFAULT_ADMIN_ROLE) {
        config.maxNftStaked = _maxNftStaked;

        emit MaxNftStakedUpdateEvent(_maxNftStaked);
    }

    function setMaxActiveOrders(uint256 _maxActiveOrders) public onlyRole(DEFAULT_ADMIN_ROLE) {
        config.maxActiveOrders = _maxActiveOrders;

        emit MaxActiveOrdersUpdateEvent(_maxActiveOrders);
    }

    function setAvailableNft(address _nftAddress, bool _available) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(Nft(_nftAddress).isAprable(), "nft is not supported");

        availableNfts[_nftAddress] = _available;

        emit AvailableNftUpdateEvent(_nftAddress, _available);
    }

    function add(uint256 _apr, uint256 _durationInDays) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_durationInDays > 0 && _durationInDays <= 365, "_duration is zero");

        PoolInfo memory pool;
        pool.apr = _apr;
        pool.duration = _durationInDays * 1 days;
        pool.total = 0;

        pools.push(pool);

        emit PoolAddedEvent(poolLength() - 1, _apr, pool.duration);
    }

    function set(uint256 _pid, uint256 _apr, uint256 _durationInDays) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = pools[_pid];

        require(_durationInDays <= 365, "_durationInDays is error");

        pool.apr = _apr;
        pool.duration = _durationInDays * 1 days;

        emit PoolUpdatedEvent(_pid, _apr, pool.duration);
    }

}