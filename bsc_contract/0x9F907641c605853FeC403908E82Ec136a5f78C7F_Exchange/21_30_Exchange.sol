// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IInsuranceExchange.sol";
import "./interfaces/IMark2Market.sol";
import "./interfaces/IPortfolioManager.sol";
import "./SionToken.sol";
import "./libraries/WadRayMath.sol";
import "./PayoutListener.sol";
import "./interfaces/IBlockGetter.sol";
import "hardhat/console.sol";

contract Exchange is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using WadRayMath for uint256;
    bytes32 public constant FREE_RIDER_ROLE = keccak256("FREE_RIDER_ROLE");
    bytes32 public constant PORTFOLIO_AGENT_ROLE = keccak256("PORTFOLIO_AGENT_ROLE");
    bytes32 public constant UNIT_ROLE = keccak256("UNIT_ROLE");

    uint256 public constant LIQ_DELTA_DM   = 1000000000000000000; // 1e6
    uint256 public constant FISK_FACTOR_DM = 100000;  // 1e5


    // ---  fields

    SionToken public usdPlus;
    IERC20 public usdc; // asset name

    IPortfolioManager public portfolioManager; //portfolio manager contract
    IMark2Market public mark2market;

    uint256 public buyFee;
    uint256 public buyFeeDenominator; // ~ 100 %

    uint256 public redeemFee;
    uint256 public redeemFeeDenominator; // ~ 100 %

    // next payout time in epoch seconds
    uint256 public nextPayoutTime;

    // period between payouts in seconds, need to calc nextPayoutTime
    uint256 public payoutPeriod;

    // range of time for starting near next payout time at seconds
    // if time in [nextPayoutTime-payoutTimeRange;nextPayoutTime+payoutTimeRange]
    //    then payouts can be started by payout() method anyone
    // else if time more than nextPayoutTime+payoutTimeRange
    //    then payouts started by any next buy/redeem
    uint256 public payoutTimeRange;

    IPayoutListener public payoutListener;

    // last block number when buy/redeem was executed
    uint256 public lastBlockNumber;

    uint256 public abroadMin;
    uint256 public abroadMax;

    address public insurance;

    uint256 public oracleLoss;
    uint256 public oracleLossDenominator;

    uint256 public compensateLoss;
    uint256 public compensateLossDenominator;

    address public profitRecipient;

    address public blockGetter;

    SionToken public sionToken;
    IERC20 public usdt; // asset name

    // ---  events

    event TokensUpdated(address sionToken, address asset);
    event Mark2MarketUpdated(address mark2market);
    event PortfolioManagerUpdated(address portfolioManager);
    event BuyFeeUpdated(uint256 fee, uint256 feeDenominator);
    event RedeemFeeUpdated(uint256 fee, uint256 feeDenominator);
    event PayoutTimesUpdated(uint256 nextPayoutTime, uint256 payoutPeriod, uint256 payoutTimeRange);
    event PayoutListenerUpdated(address payoutListener);
    event InsuranceUpdated(address insurance);
    event BlockGetterUpdated(address blockGetter);

    event EventExchange(string label, uint256 amount, uint256 fee, address sender, string referral);
    event PayoutEvent(
        uint256 totalSionToken,
        uint256 totalAsset,
        uint256 totallyAmountPaid,
        uint256 newLiquidityIndex
    );
    event PaidBuyFee(uint256 amount, uint256 feeAmount);
    event PaidRedeemFee(uint256 amount, uint256 feeAmount);
    event NextPayoutTime(uint256 nextPayoutTime);
    event OnNotEnoughLimitRedeemed(address token, uint256 amount);
    event PayoutAbroad(uint256 delta, uint256 deltaSionToken);
    event Abroad(uint256 min, uint256 max);
    event ProfitRecipientUpdated(address recipient);
    event OracleLossUpdate(uint256 oracleLoss, uint256 denominator);
    event CompensateLossUpdate(uint256 compensateLoss, uint256 denominator);

    // ---  modifiers

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted to admins");
        _;
    }

    modifier onlyPortfolioAgent() {
        require(hasRole(PORTFOLIO_AGENT_ROLE, msg.sender), "Restricted to Portfolio Agent");
        _;
    }

    modifier oncePerBlock() {

        uint256 blockNumber;

        // Arbitrum when call block.number return blockNumber from L1(mainnet)
        // To get a valid block, we use a BlockGetter contract with its own implementation of getting a block.number from L2(Arbitrum)

        // What is it needed?
        // 15 seconds ~ average time for a new block to appear on the mainnet

        // User1 send transaction mint:
        // - l1.blockNumber = 100
        // - l2.blockNumber = 60000
        // 5 seconds later
        // User2 send transaction mint:
        // - l1.blockNumber = 100
        // - l2.blockNumber = 60001
        // If blockNumber from L1 then tx be revert("Only once in block")
        // If blockNumber from L2 then tx be success mint!

        if(blockGetter != address(0)){
            blockNumber = IBlockGetter(blockGetter).getNumber();
        }else {
            blockNumber = block.number;
        }

        if (!hasRole(FREE_RIDER_ROLE, msg.sender)) {
            require(lastBlockNumber < blockNumber, "Only once in block");
        }
        lastBlockNumber = blockNumber;
        _;
    }

    modifier onlyUnit(){
        require(hasRole(UNIT_ROLE, msg.sender), "Restricted to Unit");
        _;
    }

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        buyFee = 40;
        // ~ 100 %
        buyFeeDenominator = 100000;

        redeemFee = 40;
        // ~ 100 %
        redeemFeeDenominator = 100000;

        // 1637193600 = 2021-11-18T00:00:00Z
        nextPayoutTime = 1637193600;

        payoutPeriod = 24 * 60 * 60;

        payoutTimeRange = 15 * 60;

        abroadMin = 999760;
        abroadMax = 1000350;

        _setRoleAdmin(FREE_RIDER_ROLE, PORTFOLIO_AGENT_ROLE);
        _setRoleAdmin(UNIT_ROLE, PORTFOLIO_AGENT_ROLE);

        oracleLossDenominator = 100000;
        compensateLossDenominator = 100000;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(DEFAULT_ADMIN_ROLE)
    override
    {}

    // Support old version - need call after update

    function changeAdminRoles() external onlyAdmin {
        _setRoleAdmin(FREE_RIDER_ROLE, PORTFOLIO_AGENT_ROLE);
        _setRoleAdmin(UNIT_ROLE, PORTFOLIO_AGENT_ROLE);
    }


    // ---  setters Admin

    function setTokens(address _sionToken, address _asset) external onlyAdmin {
        require(_sionToken != address(0), "Zero address not allowed");
        require(_asset != address(0), "Zero address not allowed");
        sionToken = SionToken(_sionToken);
        usdt = IERC20(_asset);
        emit TokensUpdated(_sionToken, _asset);
    }

    function setPortfolioManager(address _portfolioManager) external onlyAdmin {
        require(_portfolioManager != address(0), "Zero address not allowed");
        portfolioManager = IPortfolioManager(_portfolioManager);
        emit PortfolioManagerUpdated(_portfolioManager);
    }

    function setMark2Market(address _mark2market) external onlyAdmin {
        require(_mark2market != address(0), "Zero address not allowed");
        mark2market = IMark2Market(_mark2market);
        emit Mark2MarketUpdated(_mark2market);
    }

    function setPayoutListener(address _payoutListener) external onlyAdmin {
        payoutListener = IPayoutListener(_payoutListener);
        emit PayoutListenerUpdated(_payoutListener);
    }

    function setInsurance(address _insurance) external onlyAdmin {
        require(_insurance != address(0), "Zero address not allowed");
        insurance = _insurance;
        emit InsuranceUpdated(_insurance);
    }

    function setBlockGetter(address _blockGetter) external onlyAdmin {
        // blockGetter can be empty
        blockGetter = _blockGetter;
        emit BlockGetterUpdated(_blockGetter);
    }

    function setProfitRecipient(address _profitRecipient) external onlyAdmin {
        require(_profitRecipient != address(0), "Zero address not allowed");
        profitRecipient = _profitRecipient;
        emit ProfitRecipientUpdated(_profitRecipient);
    }

    // ---  setters Portfolio Manager

    function setBuyFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        buyFee = _fee;
        buyFeeDenominator = _feeDenominator;
        emit BuyFeeUpdated(buyFee, buyFeeDenominator);
    }

    function setRedeemFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        redeemFee = _fee;
        redeemFeeDenominator = _feeDenominator;
        emit RedeemFeeUpdated(redeemFee, redeemFeeDenominator);
    }


    function setOracleLoss(uint256 _oracleLoss,  uint256 _denominator) external onlyPortfolioAgent {
        require(_denominator != 0, "Zero denominator not allowed");
        oracleLoss = _oracleLoss;
        oracleLossDenominator = _denominator;
        emit OracleLossUpdate(_oracleLoss, _denominator);
    }

    function setCompensateLoss(uint256 _compensateLoss,  uint256 _denominator) external onlyPortfolioAgent {
        require(_denominator != 0, "Zero denominator not allowed");
        compensateLoss = _compensateLoss;
        compensateLossDenominator = _denominator;
        emit CompensateLossUpdate(_compensateLoss, _denominator);
    }


    function setAbroad(uint256 _min, uint256 _max) external onlyPortfolioAgent {
        abroadMin = _min;
        abroadMax = _max;
        emit Abroad(abroadMin, abroadMax);
    }

    function setPayoutTimes(
        uint256 _nextPayoutTime,
        uint256 _payoutPeriod,
        uint256 _payoutTimeRange
    ) external onlyPortfolioAgent {
        require(_nextPayoutTime != 0, "Zero _nextPayoutTime not allowed");
        require(_payoutPeriod != 0, "Zero _payoutPeriod not allowed");
        require(_nextPayoutTime > _payoutTimeRange, "_nextPayoutTime shoud be more than _payoutTimeRange");
        nextPayoutTime = _nextPayoutTime;
        payoutPeriod = _payoutPeriod;
        payoutTimeRange = _payoutTimeRange;
        emit PayoutTimesUpdated(nextPayoutTime, payoutPeriod, payoutTimeRange);
    }

    // ---  logic

    function pause() public onlyPortfolioAgent {
        _pause();
    }

    function unpause() public onlyPortfolioAgent {
        _unpause();
    }

    struct MintParams {
        address asset;   // USDT
        uint256 amount;  // amount asset
        string referral; // code from Referral Program -> if not have -> set empty
    }

    // Minting Sion in exchange for an asset

    function mint(MintParams calldata params) external whenNotPaused oncePerBlock returns (uint256) {
        console.log("mint!");
        return _buy(params.asset, params.amount, params.referral);
    }

    // Deprecated method - not recommended for use
    function buy(address _asset, uint256 _amount) external whenNotPaused oncePerBlock returns (uint256) {
        console.log("buy!");
        return _buy(_asset, _amount, "");
    }


    /**
     * @param _asset Asset to spend
     * @param _amount Amount of asset to spend
     * @param _referral Referral code
     * @return Amount of minted Sion to caller
     */
    function _buy(address _asset, uint256 _amount, string memory _referral) internal returns (uint256) {
        console.log('doing a mint/buy on exchange');
        console.log(_asset);
        console.log(address(usdt));
        console.log(_amount);
        console.log('currentbalance:');
        console.log(usdt.balanceOf(msg.sender));
        require(_asset == address(usdt), "Only asset available for buy");

        uint256 currentBalance = usdt.balanceOf(msg.sender);
        require(currentBalance >= _amount, "Not enough tokens to buy");

        require(_amount > 0, "Amount of asset is zero");

        uint256 usdPlusAmount = _assetToRebase(_amount);
        console.log('usdPlusAmount');
        console.log(usdPlusAmount);
        require(usdPlusAmount > 0, "Amount of Sion is zero");

        uint256 _targetBalance = usdt.balanceOf(address(portfolioManager)) + _amount;
        usdt.transferFrom(msg.sender, address(portfolioManager), _amount);
        require(usdt.balanceOf(address(portfolioManager)) == _targetBalance, 'pm balance != target');
        console.log('calling pm.deposit()');
        portfolioManager.deposit();

        uint256 buyFeeAmount;
        uint256 buyAmount;
        (buyAmount, buyFeeAmount) = _takeFee(usdPlusAmount, true);

        sionToken.mint(msg.sender, buyAmount);

        emit EventExchange("mint", buyAmount, buyFeeAmount, msg.sender, _referral);

        return buyAmount;
    }

    /**
     * @param _asset Asset to redeem
     * @param _amount Amount of Sion to burn
     * @return Amount of asset unstacked and transferred to caller
     */
    function redeem(address _asset, uint256 _amount) external whenNotPaused oncePerBlock returns (uint256) {
        require(_asset == address(usdt), "Only asset available for redeem");
        require(_amount > 0, "Amount of Sion is zero");
        require(sionToken.balanceOf(msg.sender) >= _amount, "Not enough tokens to redeem");

        uint256 assetAmount = _rebaseToAsset(_amount);
        require(assetAmount > 0, "Amount of asset is zero");

        uint256 redeemFeeAmount;
        uint256 redeemAmount;

        (redeemAmount, redeemFeeAmount) = _takeFee(assetAmount, false);

        portfolioManager.withdraw(redeemAmount);

        // Or just burn from sender
        sionToken.burn(msg.sender, _amount);

        require(usdt.balanceOf(address(this)) >= redeemAmount, "Not enough for transfer redeemAmount");
        usdt.transfer(msg.sender, redeemAmount);

        emit EventExchange("redeem", redeemAmount, redeemFeeAmount, msg.sender, "");

        return redeemAmount;
    }


    function _takeFee(uint256 _amount, bool isBuy) internal view returns (uint256, uint256){

        uint256 fee = isBuy ? buyFee : redeemFee;
        uint256 feeDenominator = isBuy ? buyFeeDenominator : redeemFeeDenominator;

        uint256 feeAmount;
        uint256 resultAmount;
        if (!hasRole(FREE_RIDER_ROLE, msg.sender)) {
            feeAmount = (_amount * fee) / feeDenominator;
            resultAmount = _amount - feeAmount;
        } else {
            resultAmount = _amount;
        }

        return (resultAmount, feeAmount);
    }


    function _rebaseToAsset(uint256 _amount) internal view returns (uint256){

        uint256 assetDecimals = IERC20Metadata(address(usdt)).decimals();
        uint256 usdPlusDecimals = sionToken.decimals();
        if (assetDecimals > usdPlusDecimals) {
            _amount = _amount * (10 ** (assetDecimals - usdPlusDecimals));
        } else {
            _amount = _amount / (10 ** (usdPlusDecimals - assetDecimals));
        }

        return _amount;
    }


    function _assetToRebase(uint256 _amount) internal view returns (uint256){

        uint256 assetDecimals = IERC20Metadata(address(usdt)).decimals();
        uint256 usdPlusDecimals = sionToken.decimals();
        if (assetDecimals > usdPlusDecimals) {
            _amount = _amount / (10 ** (assetDecimals - usdPlusDecimals));
        } else {
            _amount = _amount * (10 ** (usdPlusDecimals - assetDecimals));
        }
        return _amount;
    }


    function payout() external whenNotPaused onlyUnit {
        // if (block.timestamp + payoutTimeRange < nextPayoutTime) {
        //     return;
        // }
        // **** TEMP REMOVED TIMESTAMP CHECK SO IT CAN BE CALLED DURING DEV

        // 0. call claiming reward and balancing on PM
        // 1. get current amount of Sion
        // 2. get total sum of asset we can get from any source
        // 3. calc difference between total count of Sion and asset
        // 4. update Sion liquidity index

        portfolioManager.claimAndBalance();

        /// NEW SIMPLIFIED
        uint256 totalSionTokenSupplyRay = sionToken.scaledTotalSupply();
        uint256 totalSionTokenSupply = totalSionTokenSupplyRay.rayToWad();
        uint256 totalAsset = mark2market.totalNetAssets();

        uint256 assetDecimals = IERC20Metadata(address(usdt)).decimals();
        uint256 usdPlusDecimals = sionToken.decimals();
        if (assetDecimals > usdPlusDecimals) {
            totalAsset = totalAsset / (10 ** (assetDecimals - usdPlusDecimals));
        } else {
            totalAsset = totalAsset * (10 ** (usdPlusDecimals - assetDecimals));
        }

        uint difference;
        if (totalAsset <= totalSionTokenSupply) {
            difference = totalSionTokenSupply - totalAsset;
        } else {
            difference = totalAsset - totalSionTokenSupply;
        }

        uint256 totalAssetSupplyRay = totalAsset.wadToRay();
        // in ray
        uint256 newLiquidityIndex = totalAssetSupplyRay.rayDiv(totalSionTokenSupplyRay);
        uint256 currentLiquidityIndex = sionToken.liquidityIndex();

        uint256 delta = (newLiquidityIndex * 1e6) / currentLiquidityIndex;
        console.log('delta: %s abroadMin: %s',delta,abroadMin);
        if (delta <= abroadMin) {
            revert('Delta abroad:min');
        }

        if (abroadMax <= delta) {
            revert('Delta abroad:max');
        }

        // set newLiquidityIndex
        sionToken.setLiquidityIndex(newLiquidityIndex);


        // notify listener about payout done
        if (address(payoutListener) != address(0)) {
            payoutListener.payoutDone();
        }

        emit PayoutEvent(
           totalSionTokenSupply,
            totalAsset,
            difference,
            newLiquidityIndex
        );

        // Update next payout time. Cycle for preventing gaps
        // Allow execute payout every day in one time (10:00)

        // If we cannot execute payout (for any reason) in 10:00 and execute it in 15:00
        // then this cycle make 1 iteration and next payout time will be same 10:00 in next day

        // If we cannot execute payout more than 2 days and execute it in 15:00
        // then this cycle make 3 iteration and next payout time will be same 10:00 in next day

        for (; block.timestamp >= nextPayoutTime - payoutTimeRange;) {
            nextPayoutTime = nextPayoutTime + payoutPeriod;
        }
        emit NextPayoutTime(nextPayoutTime);
    }
}