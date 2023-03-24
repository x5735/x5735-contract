//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface Aggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract MookyBSCICO is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using ECDSA for bytes32;
    uint256 public salePrice;
    uint256 public totalTokensSold;
    uint256 public totalRaise;
    uint256 public startTime;
    uint256 public endTime;
    bool public claimStart;
    address public saleToken;
    address public icoCouponAdmin;
    uint256 public couponBonus;

    IERC20Upgradeable public BUSDInterface;
    IERC20Upgradeable public USDTInterface;
    Aggregator internal aggregatorInterface;
    // https://docs.chain.link/docs/ethereum-addresses/ => (ETH / USD)

    mapping(address => uint256) public userInvested;
    mapping(address => uint256) public userDeposits;
    mapping(address => bool) public hasClaimed;
    mapping(bytes32 => bool) public couponCodeUsed;

    event TokensBought(
        address indexed user,
        uint256 indexed tokensBought,
        address indexed purchaseToken,
        uint256 amountPaid,
        uint256 timestamp
    );

    event TokensClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    modifier checkClaimStatus() {
        require(!claimStart, "claim already start");
        _;
    }

    modifier checkCouponCode(bytes32 _code, bytes calldata _sig) {
        require(!couponCodeUsed[_code], "coupon not valid");
        bytes32 hash = _code.toEthSignedMessageHash();
        require(
            (address(hash.recover(_sig)) == address(icoCouponAdmin)),
            "coupon not valid"
        );
        couponCodeUsed[_code] = true;
        _;
    }

    function initialize(
        address _oracle,
        address _usdt,
        address _busd
    ) external initializer {
        require(_oracle != address(0), "Zero aggregator address");
        require(_usdt != address(0), "Zero USDT address");
        require(_busd != address(0), "Zero BUSD address");

        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        salePrice = 0.0000025 * (10**18); //0.0000025 USD
        aggregatorInterface = Aggregator(_oracle);
        USDTInterface = IERC20Upgradeable(_usdt);
        BUSDInterface = IERC20Upgradeable(_busd);
    }

    receive() external payable {
        buyWithBnb(msg.value);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changeICOCouponAdmin(address _newadmin) external onlyOwner {
        icoCouponAdmin = _newadmin;
    }

    function changecouponBonus(uint256 _newBonus) external onlyOwner {
        couponBonus = _newBonus;
    }

    function changeClaimStatus(bool _status) external onlyOwner {
        claimStart = _status;
    }

    function changeSalePrice(uint256 newprice) external onlyOwner {
        salePrice = newprice;
    }

    function changeSaleTime(uint256 _startTime, uint256 _endTime)
        external
        onlyOwner
    {
        startTime = _startTime;
        endTime = _endTime;
    }

    function calculatePrice(uint256 _amount, bool _isCouponapplied)
        external
        view
        returns (uint256 totalValue)
    {
        uint256 allocation;
        allocation = ((_amount * 1 ether) / salePrice);
        if (_isCouponapplied) {   
            return allocation + (allocation * couponBonus) / 100;
        }
        return allocation;
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    function buyWithUSDT(uint256 amount)
        external
        whenNotPaused
        checkClaimStatus
        returns (bool)
    {
        uint256 allocatedamount = (amount * 1 ether) / salePrice;
        buyUsdt(_msgSender(), amount, allocatedamount);
        return true;
    }

    function buyWithUSDTCoupon(
        uint256 amount,
        bytes32 _code,
        bytes calldata sig
    )
        external
        whenNotPaused
        checkClaimStatus
        checkCouponCode(_code, sig)
        nonReentrant
        returns (bool)
    {
        uint256 allocatedamount = (amount * 1 ether) / salePrice;
        uint256 extraBonus = (allocatedamount * couponBonus) / 100;
        buyUsdt(_msgSender(), amount, allocatedamount + extraBonus);
        return true;
    }

    function buyUsdt(
        address _user,
        uint256 usdAmount,
        uint256 allocatedamount
    ) internal {
        userDeposits[_user] += allocatedamount;
        userInvested[_user] += (usdAmount);
        totalTokensSold += allocatedamount;
        totalRaise += usdAmount;

        uint256 ourAllowance = USDTInterface.allowance(_user, address(this));
        require(usdAmount <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(USDTInterface).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _user,
                owner(),
                usdAmount
            )
        );
        require(success, "Token payment failed");
        emit TokensBought(
            _user,
            allocatedamount,
            address(USDTInterface),
            usdAmount,
            block.timestamp
        );
    }

    function buyWithBUSD(uint256 amount)
        external
        whenNotPaused
        checkClaimStatus
        returns (bool)
    {
        uint256 allocatedamount = (amount * 1 ether) / salePrice;
        buyBusd(_msgSender(), amount, allocatedamount);
        return true;
    }

    function buyWithBUSDCoupon(
        uint256 amount,
        bytes32 _code,
        bytes calldata sig
    )
        external
        whenNotPaused
        checkClaimStatus
        checkCouponCode(_code, sig)
        nonReentrant
        returns (bool)
    {
        uint256 allocatedamount = (amount * 1 ether) / salePrice;
        uint256 extraBonus = (allocatedamount * couponBonus) / 100;
        buyBusd(_msgSender(), amount, allocatedamount + extraBonus);
        return true;
    }

    function buyBusd(
        address _user,
        uint256 usdAmount,
        uint256 allocatedamount
    ) internal {
        userDeposits[_user] += allocatedamount;
        userInvested[_user] += (usdAmount);
        totalTokensSold += allocatedamount;
        totalRaise += usdAmount;

        uint256 ourAllowance = BUSDInterface.allowance(_user, address(this));
        require(usdAmount <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(BUSDInterface).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _user,
                owner(),
                usdAmount
            )
        );
        require(success, "Token payment failed");
        emit TokensBought(
            _msgSender(),
            allocatedamount,
            address(BUSDInterface),
            usdAmount,
            block.timestamp
        );
    }

    function buyWithBnb(uint256 amount)
        public
        payable
        whenNotPaused
        checkClaimStatus
        nonReentrant
        returns (bool)
    {
        require(msg.value == amount, "buyWithBnb: wrong amount");
        uint256 bnbToUsd = ((amount * getLatestPrice()));
        uint256 allocatedamount = (bnbToUsd) / salePrice;
        buyBnb(_msgSender(), bnbToUsd, allocatedamount);
        return true;
    }

    function buyWithBnbCoupon(
        uint256 amount,
        bytes32 _code,
        bytes calldata sig
    )
        external
        payable
        whenNotPaused
        checkClaimStatus
        checkCouponCode(_code, sig)
        nonReentrant
        returns (bool)
    {
        require(msg.value == amount, "buyWithBnb: wrong amount");
        uint256 bnbToUsd = ((amount * getLatestPrice()));
        uint256 allocatedamount = (bnbToUsd) / salePrice;
        uint256 extraBonus = (allocatedamount * couponBonus) / 100;
        buyBnb(_msgSender(), bnbToUsd, allocatedamount + extraBonus);
        return true;
    }

    function buyBnb(
        address _user,
        uint256 bnbToUsd,
        uint256 allocatedamount
    ) internal {
        userDeposits[_user] += allocatedamount;
        uint256 investamount = bnbToUsd / 1 ether;
        userInvested[_user] += (investamount);
        totalTokensSold += allocatedamount;
        totalRaise += investamount;
        sendValue(payable(owner()), address(this).balance);
        emit TokensBought(
            _user,
            allocatedamount,
            address(0),
            investamount,
            block.timestamp
        );
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "BNB Payment failed");
    }

    function setSaleToken(address _saleToken) external onlyOwner {
        saleToken = _saleToken;
    }

    function claim() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(claimStart, "Claim has not started yet");
        require(!hasClaimed[_msgSender()], "Already claimed");
        hasClaimed[_msgSender()] = true;
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to claim");
        delete userDeposits[_msgSender()];
        IERC20Upgradeable(saleToken).transfer(_msgSender(), amount);
        emit TokensClaimed(_msgSender(), amount, block.timestamp);
        return true;
    }

    function withdrawBnb(address payable _admin) external onlyOwner {
        (bool success, ) = _admin.call{value: address(this).balance}("");
        require(success, "BNB Payment failed");
    }

    function withdrawTokens(address _token, address _admin) external onlyOwner {
        uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).transfer(_admin, amount);
    }

    function changeAggregator(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Zero aggregator address");
        aggregatorInterface = Aggregator(_oracle);
    }
}