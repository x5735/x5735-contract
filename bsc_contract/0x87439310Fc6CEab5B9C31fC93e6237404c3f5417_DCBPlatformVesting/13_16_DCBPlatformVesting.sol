// SPDX-License-Identifier: MIT

//** DCB vesting Contract */
//** Author Aaron & Aceson : DCB 2023.2 */

pragma solidity 0.8.19;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeMath } from "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import { IDCBPlatformVesting } from "./interfaces/IDCBPlatformVesting.sol";
import { IDCBTiers } from "./interfaces/IDCBTiers.sol";
import { DateTime } from "./libraries/DateTime.sol";

contract DCBPlatformVesting is Ownable, DateTime, Initializable, IDCBPlatformVesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    VestingPool public vestingPool;

    // refund total values
    uint256 public totalVestedValue;
    uint256 public totalRefunded;
    uint256 public totalVestedToken;
    uint256 public totalReturnedToken;
    uint256 public totalTokenOnSale;

    uint256 public gracePeriod;
    address public innovator;
    address public paymentReceiver;
    address public router;
    address[] public path;
    bool public claimed;

    IERC20 public vestedToken;
    IERC20 public paymentToken;
    IDCBTiers public tiers;
    address public factory;

    event CrowdfundingInitialized(ContractSetup c, VestingSetup p, BuybackSetup b);
    event TokenClaimInitialized(address _token, VestingSetup p);
    event VestingStrategyAdded(uint256 _cliff, uint256 _start, uint256 _duration, uint256 _initialUnlockPercent);
    event RaisedFundsClaimed(uint256 payment, uint256 remaining);
    event BuybackAndBurn(uint256 amount);
    event SetVestingStartTime(uint256 _newStart);

    modifier onlyInnovator() {
        require(msg.sender == innovator, "Invalid access");
        _;
    }

    modifier userInWhitelist(address _wallet) {
        require(vestingPool.hasWhitelist[_wallet].active, "Not in whitelist");
        _;
    }

    function initializeCrowdfunding(
        ContractSetup memory c,
        VestingSetup memory p,
        BuybackSetup memory b
    )
        external
        initializer
    {
        innovator = c._innovator;
        paymentReceiver = c._paymentReceiver;
        vestedToken = IERC20(c._vestedToken);
        paymentToken = IERC20(c._paymentToken);
        tiers = IDCBTiers(c._tiers);
        gracePeriod = c._gracePeriod;
        totalTokenOnSale = c._totalTokenOnSale;
        router = b.router;
        path = b.path;

        paymentToken.approve(router, type(uint256).max);
        _transferOwnership(msg.sender);
        factory = msg.sender;

        addVestingStrategy(p._cliff, p._startTime, p._duration, p._initialUnlockPercent);

        emit CrowdfundingInitialized(c, p, b);
    }

    function initializeTokenClaim(address _token, VestingSetup memory p) external initializer {
        vestedToken = IERC20(_token);
        _transferOwnership(msg.sender);
        factory = msg.sender;

        addVestingStrategy(p._cliff, p._startTime, p._duration, p._initialUnlockPercent);

        emit TokenClaimInitialized(_token, p);
    }

    function addVestingStrategy(
        uint256 _cliff,
        uint256 _start,
        uint256 _duration,
        uint256 _initialUnlockPercent
    )
        internal
        returns (bool)
    {
        vestingPool.cliff = _start.add(_cliff);
        vestingPool.start = _start;
        vestingPool.duration = _duration;
        vestingPool.initialUnlockPercent = _initialUnlockPercent;

        emit VestingStrategyAdded(_cliff, _start, _duration, _initialUnlockPercent);
        return true;
    }

    function setVestingStartTime(uint256 _newStart) external {
        require(msg.sender == factory, "Only factory");
        uint256 cliff = vestingPool.cliff - vestingPool.start;
        vestingPool.start = _newStart;
        vestingPool.cliff = _newStart + cliff;

        emit SetVestingStartTime(_newStart);
    }

    function refund() external userInWhitelist(msg.sender) {
        uint256 idx = vestingPool.hasWhitelist[msg.sender].arrIdx;
        WhitelistInfo storage whitelist = vestingPool.whitelistPool[idx];

        require(
            block.timestamp < vestingPool.start + gracePeriod && block.timestamp > vestingPool.start,
            "Not in grace period"
        );
        require(!whitelist.refunded, "user already refunded");
        require(whitelist.distributedAmount == 0, "user already claimed");

        (, uint256 tier, uint256 multi) = tiers.getTierOfUser(msg.sender);
        (,, uint256 refundFee) = tiers.tierInfo(tier);

        if (multi > 1) {
            uint256 multiReduction = (multi - 1) * 50;
            refundFee = refundFee > multiReduction ? refundFee - multiReduction : 0;
        }

        uint256 fee = whitelist.value * refundFee / 10_000;
        uint256 refundAmount = whitelist.value - fee;

        whitelist.refunded = true;
        whitelist.refundDate = block.timestamp;
        totalRefunded += whitelist.value;
        totalReturnedToken += whitelist.amount;

        // Transfer BUSD to user sub some percent of fee
        paymentToken.safeTransfer(msg.sender, refundAmount);
        if (fee > 0) {
            _doBuybackAndBurn(fee);
        }

        emit Refund(msg.sender, refundAmount);
    }

    function transferOwnership(address newOwner) public override(Ownable, IDCBPlatformVesting) onlyOwner {
        super.transferOwnership(newOwner);
    }

    function claimRaisedFunds() external onlyInnovator {
        require(block.timestamp > gracePeriod + vestingPool.start, "grace period in progress");
        require(!claimed, "already claimed");

        // payment amount = total value - total refunded
        uint256 amountPayment = totalVestedValue - totalRefunded;
        // calculate fee of 5%
        uint256 decubateFee = amountPayment * 5 / 100;

        amountPayment -= decubateFee;

        // amount of project tokens to return = amount not sold + amount refunded
        uint256 amountTokenToReturn = totalTokenOnSale - totalVestedToken + totalReturnedToken;

        claimed = true;

        // transfer payment + refunded tokens to project
        if (amountPayment > 0) {
            paymentToken.safeTransfer(innovator, amountPayment);
        }
        if (amountTokenToReturn > 0) {
            vestedToken.safeTransfer(innovator, amountTokenToReturn);
        }

        // transfer crowdfunding fee to payment receiver wallet
        if (decubateFee > 0) {
            paymentToken.safeTransfer(paymentReceiver, decubateFee);
        }

        emit RaisedFundsClaimed(amountPayment, amountTokenToReturn);
    }

    function getWhitelist(address _wallet) external view userInWhitelist(_wallet) returns (WhitelistInfo memory) {
        uint256 idx = vestingPool.hasWhitelist[_wallet].arrIdx;
        return vestingPool.whitelistPool[idx];
    }

    function getTotalToken(address _addr) external view returns (uint256) {
        IERC20 _token = IERC20(_addr);
        return _token.balanceOf(address(this));
    }

    function hasWhitelist(address _wallet) external view returns (bool) {
        return vestingPool.hasWhitelist[_wallet].active;
    }

    function getVestAmount(address _wallet) external view returns (uint256) {
        return calculateVestAmount(_wallet);
    }

    function getReleasableAmount(address _wallet) external view returns (uint256) {
        return calculateReleasableAmount(_wallet);
    }

    function getWhitelistPool() external view returns (WhitelistInfo[] memory) {
        return vestingPool.whitelistPool;
    }

    function claimDistribution(address _wallet) public returns (bool) {
        uint256 idx = vestingPool.hasWhitelist[_wallet].arrIdx;
        WhitelistInfo storage whitelist = vestingPool.whitelistPool[idx];

        require(!whitelist.refunded, "user already refunded");

        uint256 releaseAmount = calculateReleasableAmount(_wallet);

        require(releaseAmount > 0, "Zero amount");

        whitelist.distributedAmount = whitelist.distributedAmount.add(releaseAmount);

        vestedToken.safeTransfer(_wallet, releaseAmount);

        emit Claim(_wallet, releaseAmount, block.timestamp);

        return true;
    }

    function setTokenClaimWhitelist(address _wallet, uint256 _amount) public onlyOwner {
        require(!vestingPool.hasWhitelist[_wallet].active, "Already registered");
        _setWhitelist(_wallet, _amount, 0);
    }

    function setCrowdfundingWhitelist(address _wallet, uint256 _amount, uint256 _value) public onlyOwner {
        HasWhitelist memory whitelist = vestingPool.hasWhitelist[_wallet];
        WhitelistInfo[] memory pool = vestingPool.whitelistPool;

        uint256 paymentAmount = !whitelist.active ? _value : _value - pool[whitelist.arrIdx].value;
        paymentToken.safeTransferFrom(_wallet, address(this), paymentAmount);
        _setWhitelist(_wallet, _amount, _value);
    }

    function _setWhitelist(address _wallet, uint256 _amount, uint256 _value) internal {
        HasWhitelist storage whitelist = vestingPool.hasWhitelist[_wallet];
        WhitelistInfo[] storage pool = vestingPool.whitelistPool;

        if (!whitelist.active) {
            whitelist.active = true;
            whitelist.arrIdx = pool.length;

            pool.push(
                WhitelistInfo({
                    wallet: _wallet,
                    amount: _amount,
                    distributedAmount: 0,
                    value: _value,
                    joinDate: block.timestamp,
                    refundDate: 0,
                    refunded: false
                })
            );

            totalVestedValue += _value;
            totalVestedToken += _amount;
        } else {
            WhitelistInfo storage w = pool[whitelist.arrIdx];

            totalVestedValue += _value - w.value;
            totalVestedToken += _amount - w.amount;

            w.amount = _amount;
            w.value = _value;
        }

        emit SetWhitelist(_wallet, _amount, _value);
    }

    function _doBuybackAndBurn(uint256 amount) internal {
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        uint256[] memory amountsOut = _router.getAmountsOut(amount, path);
        uint256 amountOut = (amountsOut[amountsOut.length - 1] * 99) / 100; //1% slippage
        _router.swapExactTokensForTokens(amount, amountOut, path, address(0xdead), block.timestamp);

        emit BuybackAndBurn(amount);
    }

    function getVestingInfo() public view returns (VestingInfo memory) {
        return VestingInfo({
            cliff: vestingPool.cliff,
            start: vestingPool.start,
            duration: vestingPool.duration,
            initialUnlockPercent: vestingPool.initialUnlockPercent
        });
    }

    function calculateVestAmount(address _wallet) internal view userInWhitelist(_wallet) returns (uint256 amount) {
        uint256 idx = vestingPool.hasWhitelist[_wallet].arrIdx;
        WhitelistInfo memory whitelist = vestingPool.whitelistPool[idx];
        VestingPool storage vest = vestingPool;

        // initial unlock
        uint256 initial = whitelist.amount.mul(vest.initialUnlockPercent).div(1000);

        if (block.timestamp < vest.start) {
            return 0;
        } else if (block.timestamp >= vest.start && block.timestamp < vest.cliff) {
            return initial;
        } else if (block.timestamp >= vest.cliff) {
            return calculateVestAmountForLinear(whitelist, vest);
        }
    }

    function calculateVestAmountForLinear(
        WhitelistInfo memory whitelist,
        VestingPool storage vest
    )
        internal
        view
        returns (uint256)
    {
        uint256 initial = whitelist.amount.mul(vest.initialUnlockPercent).div(1000);

        uint256 remaining = whitelist.amount.sub(initial);

        if (block.timestamp >= vest.cliff.add(vest.duration)) {
            return whitelist.amount;
        } else {
            return initial + remaining.mul(block.timestamp.sub(vest.cliff)).div(vest.duration);
        }
    }

    function calculateReleasableAmount(address _wallet) internal view userInWhitelist(_wallet) returns (uint256) {
        uint256 idx = vestingPool.hasWhitelist[_wallet].arrIdx;
        return calculateVestAmount(_wallet).sub(vestingPool.whitelistPool[idx].distributedAmount);
    }
}