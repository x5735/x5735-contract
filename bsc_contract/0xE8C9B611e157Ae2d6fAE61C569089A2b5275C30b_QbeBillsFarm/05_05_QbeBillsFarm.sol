// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;
// @title Qbe-Bills LP farm Smart Contract

//  /$$$$$$  /$$$$$$$  /$$$$$$$$
// /$$__  $$| $$__  $$| $$_____/
// | $$  \ $$| $$  \ $$| $$      
// | $$  | $$| $$$$$$$ | $$$$$   
// | $$  | $$| $$__  $$| $$__/   
// | $$/$$ $$| $$  \ $$| $$      
// |  $$$$$$/| $$$$$$$/| $$$$$$$$
//  \____ $$$|_______/ |________/
//       \__/                          

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter01.sol";

/* ========== CUSTOM ERRORS ========== */

error InvalidAmount();
error InvalidAddress();
error TokensLocked();

contract QbeBillsFarm is ReentrancyGuard {
    /* ========== STATE VARIABLES ========== */

    address APE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address QBE_WBNB_LP = 0x8bAFCccC9e73E1B5F18751B0BBa09460276801F0;
    address QBE = 0xE13e2b3E521080e539260D1087c087582D1BC501;
    address WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    uint public acceptableSlippage = 500;
    uint public qbePerBnb;
    bool public qbeBillBonusActive = true;
    uint public qbeBillBonus = 1000; // 10% bonus
    uint public qbeForBillsSupply;
    uint public beansFromSoldQbe;
    struct UserInfo {
        uint qbeBalance;
        uint bnbBalance;
        uint qbeBills;
    }
    mapping(address => UserInfo) public addressToUserInfo;

    address payable public OWNER;
    address payable public teamWallet;
    IERC20 public immutable stakedToken;
    IERC20 public immutable rewardToken;
    uint public earlyUnstakeFee = 2000; // 20% fee
    uint public poolDuration=7776000;
    uint public poolStartTime;
    uint public poolEndTime;
    uint public updatedAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;
    uint private _totalStaked;
    mapping(address => uint) public userStakedBalance;
    mapping(address => uint) public userPaidRewards;
    mapping(address => uint) userRewardPerTokenPaid;
    mapping(address => uint) userRewards;
    mapping(address => bool) userStakeAgain;
    mapping(address => bool) userStakeIsRefferred;
    mapping(address => address) userRefferred;
    mapping(address => uint) refferralRewardCount;
    uint public refferralLimit = 5;
    uint public refferralPercentage = 500;

    /* ========== MODIFIERS ========== */

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if (_account != address(0)) {
            userRewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert InvalidAddress();
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);
    event QbeBillPurchased(
        address indexed user,
        uint qbeAmount,
        uint wbnbAmount,
        uint lpAmount
    );
    event QbeBillSold(address indexed user, uint qbeAmount, uint wbnbAmount);

    receive() external payable {}

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakedToken,
        address _rewardToken,
        address _router,
        address _qbe,
        address _wbnb,
        address _qbeWbnbLp
    ) {
        OWNER = payable(msg.sender);
        teamWallet = payable(0x84af88d6EDeF7b5aA630564cDeE9EfaF1937D55D);
        stakedToken = IERC20(_stakedToken);
        rewardToken = IERC20(_rewardToken);
        APE_ROUTER = _router;
        QBE = _qbe;
        WETH = _wbnb;
        QBE_WBNB_LP = _qbeWbnbLp;
        
    }

    /* ========== QBE BILL FUNCTIONS ========== */

    function purchaseQbeBill(
        address _refferralUserAddress
    ) external payable nonReentrant {
        if (userStakeAgain[msg.sender] == false) {
            userStakeAgain[msg.sender] = true;
            if (
                _refferralUserAddress != address(0) &&
                _refferralUserAddress != msg.sender
            ) {
                userRefferred[msg.sender] = _refferralUserAddress;
                userStakeIsRefferred[msg.sender] = true;
            }
        }

        uint totalBeans = msg.value;
        if (totalBeans <= 0) revert InvalidAmount();

        uint beanHalfOfBill = totalBeans / 2;
        uint beanHalfToQbe = totalBeans - beanHalfOfBill;
        uint qbeHalfOfBill = _beanToQbe(beanHalfToQbe);
        beansFromSoldQbe += beanHalfToQbe;

        uint qbeMin = _calSlippage(qbeHalfOfBill);
        uint beanMin = _calSlippage(beanHalfOfBill);

        IERC20(WETH).approve(APE_ROUTER, beanHalfOfBill);
        IERC20(QBE).approve(APE_ROUTER, qbeHalfOfBill);

        (uint _amountA, uint _amountB, uint _liquidity) = IPancakeRouter01(
            APE_ROUTER
        ).addLiquidityETH{value: beanHalfOfBill}(
            QBE,
            qbeHalfOfBill,
            qbeMin,
            beanMin,
            address(this),
            block.timestamp + 500
        );

        UserInfo memory userInfo = addressToUserInfo[msg.sender];
        userInfo.qbeBalance += qbeHalfOfBill;
        userInfo.bnbBalance += beanHalfOfBill;
        userInfo.qbeBills += _liquidity;

        addressToUserInfo[msg.sender] = userInfo;
        emit QbeBillPurchased(msg.sender, _amountA, _amountB, _liquidity);
        _stake(_liquidity);
    }

    function redeemQbeBill() external nonReentrant {
        UserInfo storage userInfo = addressToUserInfo[msg.sender];
        uint bnbOwed = userInfo.bnbBalance;
        uint qbeOwed = userInfo.qbeBalance;
        uint qbeBills = userInfo.qbeBills;
        if (qbeBills <= 0) revert InvalidAmount();
        userInfo.bnbBalance = 0;
        userInfo.qbeBalance = 0;
        userInfo.qbeBills = 0;

        _unstake(qbeBills);

        uint qbeMin = _calSlippage(qbeOwed);
        uint beanMin = _calSlippage(bnbOwed);

        IERC20(QBE_WBNB_LP).approve(APE_ROUTER, qbeBills);

        (uint _amountA, uint _amountB) = IPancakeRouter01(APE_ROUTER)
            .removeLiquidity(
                QBE,
                WETH,
                qbeBills,
                qbeMin,
                beanMin,
                address(this),
                block.timestamp + 500
            );

        // sending wbnb to the user which recieved from pancakeswap router
        IERC20(WETH).transfer(msg.sender, _amountB);
        IERC20(QBE).transfer(msg.sender, qbeOwed);
        emit QbeBillSold(msg.sender, _amountA, _amountB);
    }

    function _calSlippage(uint _amount) internal view returns (uint) {
        return (_amount * acceptableSlippage) / 10000;
    }

    function _beanToQbe(uint _amount) public returns (uint) {
        uint qbeJuice;
        uint qbeJuiceBonus;

        //confirm token0 & token1 in LP contract
        (uint qbeReserves, uint bnbReserves, ) = IPancakePair(QBE_WBNB_LP)
            .getReserves();
        qbePerBnb = qbeReserves / bnbReserves;

        if (qbeBillBonusActive) {
            qbeJuiceBonus = (qbePerBnb * qbeBillBonus) / 10000;
            uint qbePerBnbDiscounted = qbePerBnb + qbeJuiceBonus;
            qbeJuice = _amount * qbePerBnbDiscounted;
        } else qbeJuice = _amount * qbePerBnb;

        if (qbeJuice > qbeForBillsSupply) revert InvalidAmount();
        qbeForBillsSupply -= qbeJuice;

        return qbeJuice;
    }

    function fundQbeBills(uint _amount) external {
        if (_amount <= 0) revert InvalidAmount();
        qbeForBillsSupply += _amount;
        IERC20(QBE).transferFrom(msg.sender, address(this), _amount);
    }

    function defundQbeBills(uint _amount) external onlyOwner {
        if (_amount <= 0) revert InvalidAmount();
        qbeForBillsSupply -= _amount;
        IERC20(QBE).transfer(msg.sender, _amount);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _stake(uint _amount) internal updateReward(msg.sender) {
        if (_amount <= 0) revert InvalidAmount();
        userStakedBalance[msg.sender] += _amount;
        _totalStaked += _amount;
        emit Staked(msg.sender, _amount);
    }

    function _unstake(uint _amount) internal updateReward(msg.sender) {
        if (block.timestamp < poolEndTime) revert TokensLocked();
        if (_amount <= 0) revert InvalidAmount();
        if (_amount > userStakedBalance[msg.sender]) revert InvalidAmount();
        userStakedBalance[msg.sender] -= _amount;
        _totalStaked -= _amount;
        emit Unstaked(msg.sender, _amount);
    }

    function emergencyUnstake() external nonReentrant updateReward(msg.sender) {
        UserInfo storage userInfo = addressToUserInfo[msg.sender];
        uint bnbOwed = userInfo.bnbBalance;
        uint qbeOwed = userInfo.qbeBalance;
        uint qbeBills = userInfo.qbeBills;
        if (qbeBills <= 0) revert InvalidAmount();
        userInfo.bnbBalance = 0;
        userInfo.qbeBalance = 0;
        userInfo.qbeBills = 0;

        uint amount = userStakedBalance[msg.sender];
        if (amount <= 0) revert InvalidAmount();
        userStakedBalance[msg.sender] = 0;
        _totalStaked -= amount;

        uint fee = (amount * earlyUnstakeFee) / 10000;
        uint qbeBillsAfterFee = amount - fee;
        stakedToken.transfer(teamWallet, fee);

        uint qbeMin = _calSlippage(qbeOwed);
        uint beanMin = _calSlippage(bnbOwed);

        IERC20(QBE_WBNB_LP).approve(APE_ROUTER, qbeBillsAfterFee);
        (uint _amountA, uint _amountB) = IPancakeRouter01(APE_ROUTER)
            .removeLiquidity(
                QBE,
                WETH,
                qbeBillsAfterFee,
                qbeMin,
                beanMin,
                address(this),
                block.timestamp + 500
            );
        uint wbnbFee = (_amountB * earlyUnstakeFee) / 10000;
        uint bnbOwedAfterFee = _amountB - wbnbFee;
        uint qbeOwedAfterFee = qbeOwed - ((qbeOwed * earlyUnstakeFee) / 10000);

        IERC20(WETH).transfer(msg.sender, bnbOwedAfterFee);
        IERC20(QBE).transfer(msg.sender, qbeOwedAfterFee);

        emit Unstaked(msg.sender, amount);
        emit QbeBillSold(msg.sender, _amountA, _amountB);
    }

    function claimRewards() public updateReward(msg.sender) {
        uint rewards = userRewards[msg.sender];
        require(rewards > 0, "No Claim Rewards Yet!");

        userRewards[msg.sender] = 0;
        userPaidRewards[msg.sender] += rewards;
        if (userStakeIsRefferred[msg.sender] == true) {
            if (refferralRewardCount[msg.sender] < refferralLimit) {
                uint refferalReward = (rewards * refferralPercentage) / 10000;
                refferralRewardCount[msg.sender] =
                    refferralRewardCount[msg.sender] +
                    1;
                rewardToken.transfer(userRefferred[msg.sender], refferalReward);
                rewardToken.transfer(msg.sender, rewards - refferalReward);
                emit RewardPaid(userRefferred[msg.sender], refferalReward);
                emit RewardPaid(msg.sender, rewards - refferalReward);
            } else {
                rewardToken.transfer(msg.sender, rewards);
                emit RewardPaid(msg.sender, rewards);
            }
        } else {
            rewardToken.transfer(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
        }
    }

    /* ========== OWNER RESTRICTED FUNCTIONS ========== */

    function setAcceptableSlippage(uint _amount) external onlyOwner {
        if (_amount > 2000) revert InvalidAmount(); // can't set above 20%
        acceptableSlippage = _amount;
    }

    function setQbeBillBonus(uint _amount) external onlyOwner {
        if (_amount > 2000) revert InvalidAmount(); // can't set above 20%
        qbeBillBonus = _amount;
    }

    function setQbeBillBonusActive(bool _status) external onlyOwner {
        qbeBillBonusActive = _status;
    }

    function withdrawBeansFromSoldQbe() external onlyOwner {
        uint beans = beansFromSoldQbe;
        beansFromSoldQbe = 0;
        (bool success, ) = msg.sender.call{value: beans}("");
        require(success, "Transfer failed.");
    }

    function setPoolDuration(uint _duration) external onlyOwner {
        require(poolEndTime < block.timestamp, "Pool still live");
        poolDuration = _duration;
    }

    function setPoolRewards(
        uint _amount
    ) external onlyOwner updateReward(address(0)) {
        if (_amount <= 0) revert InvalidAmount();
        if (block.timestamp >= poolEndTime) {
            rewardRate = _amount / poolDuration;
        } else {
            uint remainingRewards = (poolEndTime - block.timestamp) *
                rewardRate;
            rewardRate = (_amount + remainingRewards) / poolDuration;
        }
        if (rewardRate <= 0) revert InvalidAmount();
        poolStartTime = block.timestamp;
        poolEndTime = block.timestamp + poolDuration;
        updatedAt = block.timestamp;
    }

    function topUpPoolRewards(
        uint _amount
    ) external onlyOwner updateReward(address(0)) {
        uint remainingRewards = (poolEndTime - block.timestamp) * rewardRate;
        rewardRate = (_amount + remainingRewards) / poolDuration;
        require(rewardRate > 0, "reward rate = 0");
        updatedAt = block.timestamp;
    }

    function updateTeamWallet(address payable _teamWallet) external onlyOwner {
        teamWallet = _teamWallet;
    }

    function setAddresses(
        address _router,
        address _qbeWbnbLp,
        address _qbe,
        address _wbnb
    ) external onlyOwner {
        APE_ROUTER = _router;
        QBE_WBNB_LP = _qbeWbnbLp;
        QBE = _qbe;
        WETH = _wbnb;
        setApprovaleForNewRouter();
    }

    function setApprovaleForNewRouter() internal {
        IERC20(WETH).approve(APE_ROUTER, 1000000000 * 10 ** 18);
        IERC20(QBE).approve(APE_ROUTER, 1000000000 * 10 ** 18);
        IERC20(QBE_WBNB_LP).approve(APE_ROUTER, 1000000000 * 10 ** 18);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        OWNER = payable(_newOwner);
    }

    function setEarlyUnstakeFee(uint _earlyUnstakeFee) external onlyOwner {
        require(_earlyUnstakeFee <= 2500, "the amount of fee is too damn high");
        earlyUnstakeFee = _earlyUnstakeFee;
    }

    function setRefferralPercentage(
        uint _newRefferralPercentage
    ) external onlyOwner {
        require(_newRefferralPercentage >= 0, "Invalid Refferral Percentage");
        refferralPercentage = _newRefferralPercentage;
    }

    function setRefferralLimit(uint _newRefferralLimit) external onlyOwner {
        require(_newRefferralLimit >= 0, "Invalid Refferral Limit");
        refferralLimit = _newRefferralLimit;
    }

    function emergencyRecoverBeans() public onlyOwner {
        uint balance = address(this).balance;
        uint recoverAmount = balance - beansFromSoldQbe;
        (bool success, ) = msg.sender.call{value: recoverAmount}("");
        require(success, "Transfer failed.");
    }

    function emergencyRecoverBEP20(
        IERC20 _token,
        uint _amount
    ) public onlyOwner {
        if (_token == stakedToken) {
            uint recoverAmount = _token.balanceOf(address(this)) - _totalStaked;
            _token.transfer(msg.sender, recoverAmount);
        } else if (_token == rewardToken) {
            uint availRecoverAmount = _token.balanceOf(address(this)) -
                qbeForStakingRewards();
            require(_amount <= availRecoverAmount, "amount too high");
            _token.transfer(msg.sender, _amount);
        } else {
            _token.transfer(msg.sender, _amount);
        }
    }

    /* ========== VIEW & GETTER FUNCTIONS ========== */

    function viewUserInfo(address _user) public view returns (UserInfo memory) {
        return addressToUserInfo[_user];
    }

    function earned(address _account) public view returns (uint) {
        return
            (userStakedBalance[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) /
            1e18 +
            userRewards[_account];
    }

    function lastTimeRewardApplicable() internal view returns (uint) {
        return _min(block.timestamp, poolEndTime);
    }

    function rewardPerToken() internal view returns (uint) {
        if (_totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            _totalStaked;
    }

    function _min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }

    function qbeForStakingRewards() public view returns (uint) {
        return rewardToken.balanceOf(address(this)) - qbeForBillsSupply;
    }

    function balanceOf(address _account) external view returns (uint) {
        return userStakedBalance[_account];
    }

    function totalStaked() external view returns (uint) {
        return _totalStaked;
    }
}