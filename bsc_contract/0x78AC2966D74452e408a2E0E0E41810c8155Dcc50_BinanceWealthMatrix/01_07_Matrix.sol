// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IClimb.sol";
import "./IUniswapV2Router02.sol";

contract BinanceWealthMatrix is Ownable {
    using SafeMath for uint256;
    uint256 public constant EGGS_TO_HATCH_1MINERS = 2592000;
    uint256 public constant MAX_VAULT_TIME = 43200; // 12 hours
    address public constant USDT_ADDRESS =
        0x55d398326f99059fF775485246999027B3197955;
    IUniswapV2Router02 _router =
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uint256 public constant PSN = 10000;
    uint256 public constant PSNH = 5000;
    bool public initialized = false;
    address public feeReceiver;
    address payable climb;
    IClimb CLIMB = IClimb(address(0));
    IERC20 USDT = IERC20(USDT_ADDRESS);
    mapping(address => uint256) public hatcheryMiners;
    mapping(address => uint256) public totalInvested;
    mapping(address => uint256) public totalRedeemed;
    mapping(address => uint256) public claimedEggs;
    mapping(address => uint256) public lastHatch;
    mapping(address => address) public referrals;
    uint256 public marketEggs;

    constructor(address _climbToken) {
        CLIMB = IClimb(_climbToken);
        climb = payable(_climbToken);
        feeReceiver = CLIMB.owner();
    }

    // Invest with BNB
    function investInMatrix(address ref) public payable {
        require(initialized, "Matrix is not initialized");
        uint256 previousBalance = USDT.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = address(USDT);
        uint256 minout = _router.getAmountsOut(msg.value, path)[1].mul(995).div(
            1000
        );
        _router.swapExactETHForTokens{value: msg.value}(
            minout,
            path,
            address(this),
            block.timestamp
        );
        uint256 newBalance = USDT.balanceOf(address(this));
        uint256 usdtAmount = SafeMath.sub(newBalance, previousBalance);
        uint256 ccbalance = CLIMB.balanceOf(address(this));
        USDT.approve(address(CLIMB), usdtAmount);
        CLIMB.buy(usdtAmount);
        uint256 amount = SafeMath.sub(
            CLIMB.balanceOf(address(this)),
            ccbalance
        );

        uint256 eggsBought = calculateEggBuy(amount, newBalance);
        eggsBought = SafeMath.sub(eggsBought, devFee(eggsBought));
        claimedEggs[msg.sender] = SafeMath.add(
            claimedEggs[msg.sender],
            eggsBought
        );

        uint256 newMiners = SafeMath.div(
            claimedEggs[msg.sender],
            EGGS_TO_HATCH_1MINERS
        );
        hatcheryMiners[msg.sender] = SafeMath.add(
            hatcheryMiners[msg.sender],
            newMiners
        );

        claimedEggs[msg.sender] = 0;
        totalInvested[msg.sender] = SafeMath.add(
            totalInvested[msg.sender],
            amount
        );
        lastHatch[msg.sender] = block.timestamp;

        // send referral eggs
        if (ref == msg.sender) {
            ref = address(0);
        }
        if (
            referrals[msg.sender] == address(0) &&
            referrals[msg.sender] != msg.sender
        ) {
            referrals[msg.sender] = ref;
        }
        claimedEggs[referrals[msg.sender]] = SafeMath.add(
            claimedEggs[referrals[msg.sender]],
            SafeMath.div(eggsBought, 10)
        );

        emit Invest(msg.sender, amount);
    }

    // Invest with USDT
    function investInMatrix(address ref, uint256 usdtAmount) public {
        require(initialized, "Matrix is not initialized");
        require(
            USDT.allowance(msg.sender, address(this)) >= usdtAmount,
            "Insufficient allowance"
        );

        bool s = USDT.transferFrom(msg.sender, address(this), usdtAmount);
        require(s, "Transfer USDT failed");
        uint256 previousBalance = CLIMB.balanceOf(address(this));
        USDT.approve(address(CLIMB), usdtAmount);
        CLIMB.buy(address(this), usdtAmount);
        uint256 newBalance = CLIMB.balanceOf(address(this));
        uint256 amount = SafeMath.sub(newBalance, previousBalance);
        uint256 eggsBought = calculateEggBuy(amount, newBalance);
        eggsBought = SafeMath.sub(eggsBought, devFee(eggsBought));
        claimedEggs[msg.sender] = SafeMath.add(
            claimedEggs[msg.sender],
            eggsBought
        );

        uint256 newMiners = SafeMath.div(
            claimedEggs[msg.sender],
            EGGS_TO_HATCH_1MINERS
        );
        hatcheryMiners[msg.sender] = SafeMath.add(
            hatcheryMiners[msg.sender],
            newMiners
        );

        claimedEggs[msg.sender] = 0;
        totalInvested[msg.sender] = SafeMath.add(
            totalInvested[msg.sender],
            amount
        );
        lastHatch[msg.sender] = block.timestamp;

        // send referral eggs
        if (ref == msg.sender) {
            ref = address(0);
        }
        if (
            referrals[msg.sender] == address(0) &&
            referrals[msg.sender] != msg.sender
        ) {
            referrals[msg.sender] = ref;
        }
        claimedEggs[referrals[msg.sender]] = SafeMath.add(
            claimedEggs[referrals[msg.sender]],
            SafeMath.div(eggsBought, 10)
        );

        emit Invest(msg.sender, amount);
    }

    // Reinvest in Matrix
    function reinvestInMatrix(address ref) public {
        require(initialized, "Matrix is not initialized");
        if (ref == msg.sender) {
            ref = address(0);
        }
        if (
            referrals[msg.sender] == address(0) &&
            referrals[msg.sender] != msg.sender
        ) {
            referrals[msg.sender] = ref;
        }
        uint256 eggsUsed = getMyEggs();
        uint256 eggsValue = calculateEggSell(eggsUsed);
        uint256 fee = devFee(eggsValue);

        uint256 newMiners = SafeMath.div(
            SafeMath.sub(eggsUsed, devFee(eggsUsed)),
            EGGS_TO_HATCH_1MINERS
        );
        hatcheryMiners[msg.sender] = SafeMath.add(
            hatcheryMiners[msg.sender],
            newMiners
        );
        claimedEggs[msg.sender] = 0;
        totalInvested[msg.sender] = SafeMath.add(
            totalInvested[msg.sender],
            SafeMath.sub(eggsValue, fee)
        );
        lastHatch[msg.sender] = block.timestamp;

        // handle the fee
        uint256 dFee = SafeMath.div(fee, 5);
        uint256 burnFee = SafeMath.sub(fee, dFee);
        CLIMB.burn(burnFee);
        CLIMB.sell(address(feeReceiver), dFee);

        // send referral eggs
        claimedEggs[referrals[msg.sender]] = SafeMath.add(
            claimedEggs[referrals[msg.sender]],
            SafeMath.div(eggsUsed, 10)
        );

        // boost market to nerf miners hoarding
        marketEggs = SafeMath.add(marketEggs, SafeMath.div(eggsUsed, 5));

        emit Reinvest(msg.sender, eggsValue);
    }

    // Withdraw USDT
    function matrixRedeem() public {
        require(initialized, "Matrix is not initialized");
        uint256 hasEggs = getMyEggs();
        uint256 eggsValue = calculateEggSell(hasEggs);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs = SafeMath.add(marketEggs, hasEggs);
        totalRedeemed[msg.sender] = SafeMath.add(
            totalRedeemed[msg.sender],
            eggsValue
        );
        CLIMB.sell(msg.sender, eggsValue);
        emit Redeem(msg.sender, eggsValue);
    }

    // Withdraw BNB
    function matrixRedeemBNB() public {
        require(initialized, "Matrix is not initialized");
        uint256 hasEggs = getMyEggs();
        uint256 eggsValue = calculateEggSell(hasEggs);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs = SafeMath.add(marketEggs, hasEggs);
        uint256 previousAmount = USDT.balanceOf(address(this));
        CLIMB.sell(eggsValue);
        uint256 newAmount = USDT.balanceOf(address(this));
        uint256 amount = SafeMath.sub(newAmount, previousAmount);
        totalRedeemed[msg.sender] = SafeMath.add(
            totalRedeemed[msg.sender],
            eggsValue
        );
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = _router.WETH();
        uint256 minOut = _router.getAmountsOut(amount, path)[1].mul(995).div(
            1000
        );
        USDT.approve(address(_router), amount);
        uint256[] memory amountsOut = _router.swapExactTokensForTokens(
            amount,
            minOut,
            path,
            msg.sender,
            block.timestamp
        );
        require(amountsOut[1] > 0, "Swap failed");
        emit Redeem(msg.sender, eggsValue);
    }

    //magic trade balancing algorithm
    function calculateTrade(
        uint256 rt,
        uint256 rs,
        uint256 bs
    ) public pure returns (uint256) {
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return
            SafeMath.div(
                SafeMath.mul(PSN, bs),
                SafeMath.add(
                    PSNH,
                    SafeMath.div(
                        SafeMath.add(
                            SafeMath.mul(PSN, rs),
                            SafeMath.mul(PSNH, rt)
                        ),
                        rt
                    )
                )
            );
    }

    function calculateEggSell(uint256 eggs) public view returns (uint256) {
        return calculateTrade(eggs, marketEggs, CLIMB.balanceOf(address(this)));
    }

    function calculateEggBuy(
        uint256 amount,
        uint256 contractBalance
    ) public view returns (uint256) {
        return calculateTrade(amount, contractBalance, marketEggs);
    }

    function calculateEggBuySimple(
        uint256 amount
    ) public view returns (uint256) {
        return calculateEggBuy(amount, CLIMB.balanceOf(address(this)));
    }

    function devFee(uint256 amount) public pure returns (uint256) {
        return SafeMath.div(SafeMath.mul(amount, 5), 100);
    }

    function initializeMatrix() public onlyOwner {
        require(marketEggs == 0, "Market eggs not zero");
        initialized = true;
        marketEggs = 25920000000;
        emit Initialize(block.timestamp);
    }

    function getBalance() public view returns (uint256) {
        return CLIMB.balanceOf(address(this));
    }

    function getMyMiners() public view returns (uint256) {
        return hatcheryMiners[msg.sender];
    }

    function getMyEggs() public view returns (uint256) {
        return
            SafeMath.add(
                claimedEggs[msg.sender],
                getEggsSinceLastHatch(msg.sender)
            );
    }

    function getEggsSinceLastHatch(address adr) public view returns (uint256) {
        uint256 secondsPassed = min(
            MAX_VAULT_TIME,
            SafeMath.sub(block.timestamp, lastHatch[adr])
        );
        return SafeMath.mul(secondsPassed, hatcheryMiners[adr]);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    event Initialize(uint256 timeStamp);
    event Invest(address indexed user, uint256 climbAmount);
    event Redeem(address indexed user, uint256 climbAmount);
    event Reinvest(address indexed user, uint256 climbAmount);
}