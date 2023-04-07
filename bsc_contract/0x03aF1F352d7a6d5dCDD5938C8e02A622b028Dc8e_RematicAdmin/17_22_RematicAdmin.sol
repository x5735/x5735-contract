// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./PancakeswapInterface/IPancakeRouter02.sol";
import "./PancakeswapInterface/IPancakeFactory.sol";
import "./Interface/IRematic.sol";
import "./TokenTrackers/IDefaultTracker.sol";
import "./TokenTrackers/IHoldersPartition.sol";
import "./TokenTrackers/IFour01Programe.sol";
import "./TokenTrackers/IFour01Programe.sol";
import "./struct/Tax.sol";

contract RematicAdmin is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;

    IPancakeRouter02 public pancakeSwapV2Router;
    address public pancakeSwapPair;
    address public REWARD;

    address public pensionWallet;
    address public legalWallet;
    address public teamWallet;
    address public four01TeamWalletAddress;

    address public defaultTokenTracker;
    address public holdersPrtn;
    address public four01program;

    address public rematicAddress;

    bool public isOn401kFee;
    bool public isOnTeamFee;
    bool public isOnLegalFee;
    bool public isOnPensionFee;
    address public pairCreator;

    address public botWallet;

    bool public isLiquidationProcessing;

    event Error(string indexed messageType, string message);

    modifier onlyRematicFinace() {
        require(
            rematicAddress == address(msg.sender),
            "Message sender needs to be Rematic Contract"
        );
        _;
    }

    modifier onlyTeamWallet() {
        require(
            teamWallet == address(msg.sender),
            "Message sender needs to be Team wallet"
        );
        _;
    }

    modifier onlyBotWallet() {
        require(
            botWallet == address(msg.sender),
            "Message sender needs to be Team wallet"
        );
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _rftx,
        address _routerAddress,
        address _REWARD,
        address _pensionWallet,
        address _legalWallet,
        address _teamWallet,
        address _defaultTokenTracker,
        address _holdersPrtn,
        address _four01program,
        address _four01TeamWalletAddress
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        // init

        pancakeSwapV2Router = IPancakeRouter02(
            _routerAddress
        );
        address WBNB = pancakeSwapV2Router.WETH();
        pancakeSwapPair = address(
            IPancakeFactory(pancakeSwapV2Router.factory()).createPair(
                WBNB,
                _rftx
            )
        );

        REWARD = _REWARD;

        // liquidityFeeRate = 800;
        // pensionFeeRate = 0;
        // legalFeeRate = 0;
        // teamFeeRate = 3200;
        // holdersSdtFeeRate = 7200;
        // holdersPrtnFeeRate = 2000; // out of 10000 : 20%
        // four01FeeRate = 200; // out of 10000 : 2%

        pensionWallet = _pensionWallet;
        legalWallet = _legalWallet;
        teamWallet = _teamWallet;
        four01TeamWalletAddress = _four01TeamWalletAddress;

        defaultTokenTracker = _defaultTokenTracker;

        holdersPrtn = _holdersPrtn;

        four01program = _four01program;

        isOn401kFee = true;
        isOnTeamFee = true;
        isOnLegalFee = false;
        isOnPensionFee = false;
        pairCreator = owner();
        botWallet = 0x34f8405f796b91B9fa7ec6C0C73b0Ee002bB0d9F;

        isLiquidationProcessing = false;

        rematicAddress = _rftx;
    }

    function _authorizeUpgrade(address newImplementaion)
        internal
        override
        onlyOwner
    {}

    function setPancakeSwapRouter02Address(address _address) external onlyOwner {
        require(
            _address != address(pancakeSwapV2Router),
            "RFX: already has that address"
        );
        pancakeSwapV2Router = IPancakeRouter02(
            _address
        );
    }

    function startLiquidate() external onlyBotWallet nonReentrant {
        if (_continueParitionDistribute()) {
            return;
        }

        if (_continueLiqudate()) {
            return;
        }

        isLiquidationProcessing = true;

        uint256 tokenAmount = IRematic(rematicAddress).balanceOf(address(this));

        require(
            tokenAmount > 0,
            "No token for liquidation"
        );

        Tax memory buyTax = IRematic(rematicAddress).buyTax();
        Tax memory sellTax = IRematic(rematicAddress).sellTax();
        Tax memory tax = IRematic(rematicAddress).tax();

        //add liquidity
        _addLiquidity(buyTax, sellTax, tax, tokenAmount);

        // distribute BNB
        _distributeBNB(buyTax, sellTax, tax, tokenAmount);

        _distibuteREWARD(buyTax, sellTax, tax, tokenAmount);

        isLiquidationProcessing = false;
    }

    function swapTokensForREWARD(uint256 _amountIn) private returns (uint256) {
        address[] memory path = new address[](3);
        require(path.length <= 3, "fail");
        path[0] = rematicAddress;
        path[1] = pancakeSwapV2Router.WETH();
        path[2] = REWARD;

        IERC20(rematicAddress).approve(address(pancakeSwapV2Router), _amountIn);

        uint256 initialBUSD = IERC20(path[2]).balanceOf(address(this));

        // make the swap
        pancakeSwapV2Router
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn,
                0,
                path,
                address(this),
                block.timestamp + 200
            );

        // after swaping
        uint256 newBUSD = IERC20(path[2]).balanceOf(address(this));

        return newBUSD - initialBUSD;
    }

    function swapTokensForEth(address tokenAddress, uint256 tokenAmount)
        private
        returns (uint256)
    {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        require(path.length <= 2, "fail");
        path[0] = tokenAddress;
        path[1] = pancakeSwapV2Router.WETH();

        uint256 initialBalance = address(this).balance;

        IERC20(tokenAddress).approve(address(pancakeSwapV2Router), tokenAmount);

        // make the swap
        pancakeSwapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 200
        );

        return address(this).balance - initialBalance;
    }

    function _addLiquidity(Tax memory buyTax, Tax memory sellTax, Tax memory tax, uint256 tokenAmount) internal {

        uint256 totalPerc =_getTotalPercentage(buyTax, sellTax, tax);
        uint256 liquidityRFX = (buyTax.liquidity + sellTax.liquidity + tax.liquidity)
            .mul(tokenAmount)
            .div(totalPerc);

        //swapTokensForEth
        uint256 liquidityBNB = swapTokensForEth(rematicAddress, liquidityRFX.div(2));
        uint256 liquidityToken = liquidityRFX.sub(liquidityRFX.div(2));

        // approve token transfer to cover all possible scenarios
        IERC20(rematicAddress).approve(
            address(pancakeSwapV2Router),
            liquidityToken
        );

        // add the liquidity
        pancakeSwapV2Router.addLiquidityETH{value: liquidityBNB}(
            rematicAddress,
            liquidityToken,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            pairCreator,
            block.timestamp + 200
        );
    }

    function setPensionWallet(address _address) external onlyOwner {
        require(_address != address(0), "invalid address");
        require(pensionWallet != _address, "already set same value");
        pensionWallet = _address;
    }

    function setLegalWallet(address _address) external onlyOwner {
        require(_address != address(0), "invalid address");
        require(pensionWallet != _address, "already set same value");
        legalWallet = _address;
    }

    function setTeamWallet(address _address) external onlyOwner {
        require(_address != address(0), "invalid address");
        require(teamWallet != _address, "already set same value");
        teamWallet = _address;
    }

    receive() external payable {
        // custom function code
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function _sendBNBToPensionWallet(uint256 amount) internal {
        if (amount > 0 && isOnPensionFee) {
            (bool success, ) = address(pensionWallet).call{value: amount}(
                new bytes(0)
            );
            require(success, "_sendBNBToPensionWallet: ETH transfer failed");
        }
    }

    function _sendBNBToLegalWallet(uint256 amount) internal {
        if (amount > 0 && isOnLegalFee) {
            (bool success, ) = address(legalWallet).call{value: amount}(
                new bytes(0)
            );
            require(success, "_sendBNBToLegalWallet: ETH transfer failed");
        }
    }

    function _sendBNBToTeamWallet(uint256 amount) internal {
        if (amount > 0 && isOnTeamFee) {
            (bool success, ) = address(teamWallet).call{value: amount}(
                new bytes(0)
            );
            require(success, "_sendBNBToTeamWallet: ETH transfer failed");
        }
    }

    function _distributeRewardDividends(uint256 amount) internal {
        // send tokens to default
        if (amount > 0) {
            bool success = IERC20(rematicAddress).transfer(
                address(defaultTokenTracker),
                amount
            );
            if (success) {
                IDefaultTracker(defaultTokenTracker).distributeRewardDividends(
                    amount
                );
            }
            IDefaultTracker(defaultTokenTracker).process();
        }
    }

    function setBalance(address payable account, uint256 newBalance)
        external
        onlyRematicFinace
    {
        if (account != pancakeSwapPair) {
            // buying
            IDefaultTracker(defaultTokenTracker).setBalance(
                account,
                newBalance
            );
        }
    }

    function recordTransactionHistoryForHoldersPartition(
        address payable account,
        uint256 _txAmount,
        bool isSell
    ) external onlyRematicFinace {
        IHoldersPartition(holdersPrtn).recordTransactionHistory(
            account,
            _txAmount,
            isSell
        );
    }

    function setDefaultTokenTracker(address _address) external onlyOwner {
        require(
            _address != address(defaultTokenTracker),
            "RFX Admin: The defaultTokenTracker already has that address"
        );
        defaultTokenTracker = _address;
    }

    function setRematic(address _address) external onlyOwner {
        rematicAddress = _address;
        try
            IPancakeFactory(pancakeSwapV2Router.factory()).createPair(
                _address,
                pancakeSwapV2Router.WETH()
            )
        returns (address pair) {
            pancakeSwapPair = pair;
        } catch {
            pancakeSwapPair = IPancakeFactory(pancakeSwapV2Router.factory())
                .getPair(_address, pancakeSwapV2Router.WETH());
        }
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(pancakeSwapPair);
    }

    function _sendBUSDToHoldersPrtn(uint256 amount) internal {
        if (amount > 0) {
            bool success = IERC20(REWARD).transfer(holdersPrtn, amount);
            if (success) {
                IHoldersPartition(holdersPrtn).updateTotalBUSD();
            }
        }
    }

    function _sendBUSDToFour01TeamWallet(uint256 amount) internal {
        if (amount > 0 && isOn401kFee) {
            bool success = IERC20(REWARD).transfer(
                four01TeamWalletAddress,
                amount
            );
            if (!success) {
                
            }
        }
    }

    // config
    function excludeContractAddressesFromDividendTracker() external onlyOwner {
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(defaultTokenTracker);
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(address(this));
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(owner());
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(address(pancakeSwapV2Router));
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(pancakeSwapPair);
        address burnWallet = IRematic(rematicAddress).burnWallet();
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(burnWallet);
    }

    function _excludeFromDividendsByRematic(address _address)
        external
        onlyRematicFinace
    {
        IDefaultTracker(defaultTokenTracker)
            ._excludeFromDividendsByAdminContract(_address);
    }

    function setIsOnTeamFee(bool flag) external onlyOwner {
        require(isOnTeamFee != flag, "same value is set already");
        isOnTeamFee = flag;
    }

    function setIsOnLegalFee(bool flag) external onlyOwner {
        require(isOnLegalFee != flag, "same value is set already");
        isOnLegalFee = flag;
    }

    function setIsOnPensionFee(bool flag) external onlyOwner {
        require(isOnPensionFee != flag, "same value is set already");
        isOnPensionFee = flag;
    }

    function updateCreditPercentageMapFor401kPrograme(
        uint256 index,
        uint256 minPercentage,
        uint256 creditPercentage
    ) external onlyOwner {
        IFour01Programe(four01program).updateCreditPercentageMap(
            index,
            minPercentage,
            creditPercentage
        );
    }

    function setClaimWaitForPdividendTracker(uint256 _newValue)
        external
        onlyOwner
    {
        IHoldersPartition(holdersPrtn).setClaimWait(_newValue);
    }

    function setEligiblePeriodForPdividendTracker(uint256 _newValue)
        external
        onlyOwner
    {
        IHoldersPartition(holdersPrtn).setEligiblePeriod(_newValue);
    }

    function setEligibleMinimunBalanceForPdividendTracker(uint256 _newValue)
        external
        onlyOwner
    {
        IHoldersPartition(holdersPrtn).setEligibleMinimunBalance(_newValue);
    }

    function setTierPercentageForPdividendTracker(
        uint256 tierIndex,
        uint256 _newValue
    ) external onlyOwner {
        IHoldersPartition(holdersPrtn).setTierPercentage(tierIndex, _newValue);
    }

    function setIsOn401kFee(bool flag) external onlyOwner {
        require(isOn401kFee != flag, "same value is set already");
        isOn401kFee = flag;
    }

    function set401kWallet(address _address) external onlyOwner {
        require(four01TeamWalletAddress != _address, "already same value");
        four01TeamWalletAddress = _address;
    }

    function setHoldersPrtn(address _address) external onlyOwner {
        require(holdersPrtn != _address, "already same value");
        holdersPrtn = _address;
    }

    function set401kprogram(address _address) external onlyOwner {
        require(four01program != _address, "already same value");
        four01program = _address;
    }

    function setPancakeSwapPair(address _address) external onlyOwner {
        require(pancakeSwapPair != _address, "already same value");
        pancakeSwapPair = _address;
    }

    function setPairCreator(address _address) external onlyOwner {
        require(pairCreator != _address, "already same value");
        pairCreator = _address;
    }

    function setRewardToken(address _address) external onlyOwner {
        require(REWARD != _address, "already same value");
        REWARD = _address;
        IDefaultTracker(defaultTokenTracker).setRewardToken(_address);
    }

    function withdrawToken(address token, address account) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(address(this), account, balance);
    }

    function widthrawBNB(address _to) external onlyOwner {
        (bool success, ) = address(_to).call{value: address(this).balance}(
            new bytes(0)
        );
        require(success, "failed");
    }

    function setBotWallet(address _bot) external onlyOwner {
        require(botWallet != _bot, "same wallet already");
        botWallet = _bot;
    }

    function _continueLiqudate() internal returns (bool) {
        uint256 lastProcessedIndex = IDefaultTracker(defaultTokenTracker)
            .lastProcessedIndex();
        if (lastProcessedIndex > 0) {
            IDefaultTracker(defaultTokenTracker).process();
            return true;
        } else {
            return false;
        }
    }

    function _continueParitionDistribute() internal returns (bool) {
        bool flag = IHoldersPartition(holdersPrtn).checkIfUnfinishedWork();
        if (flag) {
            IHoldersPartition(holdersPrtn).process();
            return true;
        } else {
            return false;
        }
    }

    function mintDividendTrackerToken(address account, uint256 amount)
        external
        onlyRematicFinace
    {
        IDefaultTracker(defaultTokenTracker).mintDividendTrackerToken(
            account,
            amount
        );
    }

    function _getRFXAmountForBNB(Tax memory buyTax, Tax memory sellTax, Tax memory tax) internal pure returns(uint256 bnbRFX){
        bnbRFX = buyTax.pension
        + sellTax.pension
        + tax.pension
        + buyTax.legal
        + sellTax.legal
        + tax.legal
        + buyTax.team
        + sellTax.team
        + tax.team;
    }

    function _distributeBNB(Tax memory buyTax, Tax memory sellTax, Tax memory tax, uint256 tokenAmount) internal {

            uint256 totalPerc =_getTotalPercentage(buyTax, sellTax, tax);
            uint256 bnbPec = _getRFXAmountForBNB(buyTax, sellTax, tax);
            if(bnbPec > 0){
                uint256 bnbRFX = tokenAmount.mul(bnbPec).div(totalPerc);
                uint256 bnbAmount = swapTokensForEth(rematicAddress, bnbRFX);

                //send some rewardBNB to Pension wallet
                uint256 pAmount = bnbAmount.mul(buyTax.pension + sellTax.pension + tax.pension).div(bnbPec);
                _sendBNBToPensionWallet(pAmount);

                //send some rewardBNB to Team wallet
                uint256 tAmount = bnbAmount.mul(buyTax.team + sellTax.team + tax.team).div(bnbPec);
                _sendBNBToTeamWallet(tAmount);

                uint256 lAmount = bnbAmount - pAmount - tAmount;
                //send some rewardBNB to LegalWallet
                _sendBNBToLegalWallet(lAmount);
            }
    }

    function _distibuteREWARD (Tax memory buyTax, Tax memory sellTax, Tax memory tax, uint256 tokenAmount) internal {

        uint256 totalPerc =_getTotalPercentage(buyTax, sellTax, tax);
        //distrubute BUSD on Default Token Tracker
        uint256 hsAmount = (buyTax.divtracker + sellTax.divtracker +tax.divtracker).mul(tokenAmount).div(totalPerc);

        _distributeRewardDividends(hsAmount);

        uint256 pRewardRFX = buyTax.partition + sellTax.partition +tax.partition + buyTax.k401 + sellTax.k401 + tax.k401;
        uint256 leftTokenAmount = IRematic(rematicAddress).balanceOf(address(this));
        uint256 rewardAmount = swapTokensForREWARD(leftTokenAmount);

        uint256 hsRewardAmount = rewardAmount
            .mul(buyTax.partition + sellTax.partition + tax.partition)
            .div(pRewardRFX);
        _sendBUSDToHoldersPrtn(hsRewardAmount);

        uint256 f01RewardAmount = rewardAmount - hsRewardAmount;
        _sendBUSDToFour01TeamWallet(f01RewardAmount);
    }

    function _getTotalPercentage(Tax memory buyTax, Tax memory sellTax,Tax memory tax) internal pure returns (uint256 totalPerc) {
        totalPerc = buyTax.stake;
        totalPerc = totalPerc + buyTax.burn;
        totalPerc = totalPerc + buyTax.liquidity;
        totalPerc = totalPerc + buyTax.pension;
        totalPerc = totalPerc + buyTax.legal;
        totalPerc = totalPerc + buyTax.team;
        totalPerc = totalPerc + buyTax.divtracker;
        totalPerc = totalPerc + buyTax.partition;
        totalPerc = totalPerc + buyTax.k401;

        totalPerc = totalPerc + sellTax.burn;
        totalPerc = totalPerc + sellTax.liquidity;
        totalPerc = totalPerc + sellTax.pension;
        totalPerc = totalPerc + sellTax.legal;
        totalPerc = totalPerc + sellTax.team;
        totalPerc = totalPerc + sellTax.divtracker;
        totalPerc = totalPerc + sellTax.partition;
        totalPerc = totalPerc + sellTax.k401;

        totalPerc = totalPerc + tax.burn;
        totalPerc = totalPerc + tax.liquidity;
        totalPerc = totalPerc + tax.pension;
        totalPerc = totalPerc + tax.legal;
        totalPerc = totalPerc + tax.team;
        totalPerc = totalPerc + tax.divtracker;
        totalPerc = totalPerc + tax.partition;
        totalPerc = totalPerc + tax.k401;
    }
}