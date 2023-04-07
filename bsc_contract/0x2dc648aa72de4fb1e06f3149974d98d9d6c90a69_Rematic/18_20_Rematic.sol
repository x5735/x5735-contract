// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./PancakeswapInterface/IERC20.sol";
import "./Interface/IRematicAdmin.sol";
import "./Interface/IFSPFactory.sol";
import "./struct/TaxAmount.sol";
import "./struct/Tax.sol";

contract Rematic is
    ERC20BurnableUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeMath for uint256;

    address public adminContract;

    address public burnWallet;
    address public stakingWallet;

    bool public tradeOn;
    bool public launched;

    uint256 public maxTransferAmountRate;

    mapping(address => bool) private _excludedFromAntiWhale;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);

    uint256 public timeBetweenSells;
    uint256 public timeBetweenBuys;

    mapping(address => uint256) public transactionLockTimeSell;
    mapping(address => uint256) public transactionLockTimeBuy;

    // exlcude from fees and max transaction amount

    mapping(address => bool) private _excludedFromAntiBot;
    mapping(address => bool) private _excludedFromFee;

    uint256 public swapThreshold;

    mapping(address => bool) public stakingPoolsMap;

    address public stakingContract;

    Tax public buyTax;
    Tax public sellTax;
    Tax public tax;

    TaxAmount public sellTaxAmount;
    TaxAmount public buyTaxAmount;
    TaxAmount public taxAmount;

    event Liquidation(uint256 indexed amount);

    modifier onlyFSPPool() {
        require(stakingPoolsMap[msg.sender], "Caller is not FSP pool.");
        _;
    }

    modifier antiWhale(
        address sender,
        address recipient,
        uint256 amount
    ) {
        uint256 max = _maxTransferAmount();
        if (max > 0) {
            if (
                _excludedFromAntiWhale[sender] == false &&
                _excludedFromAntiWhale[recipient] == false
            ) {
                require(
                    amount <= max,
                    "AntiWhale: Transfer amount exceeds the maxTransferAmount"
                );
            }
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _burnWallet, address _stakingWallet)
        public
        initializer
    {
        __ERC20_init("RFX", "RFX");
        __Ownable_init();

        uint256 value = 1000000000000000;

        adminContract = 0xF555A2D0744dd53906A369AfcF8f985C4a32B0dE;

        buyTax.stake = 0;
        buyTax.burn = 0;
        buyTax.liquidity = 250;
        buyTax.pension = 0;
        buyTax.legal = 150;
        buyTax.team = 150;
        buyTax.divtracker = 125;
        buyTax.partition = 125;
        buyTax.k401 = 50;

        sellTax.stake = 0;
        sellTax.burn = 0;
        sellTax.liquidity = 3000;
        sellTax.pension = 500;
        sellTax.legal = 400;
        sellTax.team = 500;
        sellTax.divtracker = 500;
        sellTax.partition = 500;
        sellTax.k401 = 100;

        tax.stake = 0;
        tax.burn = 0;
        tax.liquidity = 0;
        tax.pension = 0;
        tax.legal = 0;
        tax.team = 0;
        tax.divtracker = 0;
        tax.partition = 0;
        tax.k401 = 0;

        burnWallet = _burnWallet;
        stakingWallet = _stakingWallet;

        maxTransferAmountRate = 500; // 5%

        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        _excludedFromAntiWhale[burnWallet] = true;

        timeBetweenSells = 100; // seconds
        timeBetweenBuys = 100;

        _mint(owner(), value * (10**18));

        tradeOn = false;

        swapThreshold = 50000000000 * (10**18);
    }

    function _authorizeUpgrade(address newImplementaion)
        internal
        override
        onlyOwner
    {}

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        super._transfer(from, to, amount);
        _updateDivBalances(from, to);
    }

    function _takeFee(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        if (_excludedFromFee[from] || _excludedFromFee[to]) {
            return 0;
        }

        address pancakeSwapPair = IRematicAdmin(adminContract)
            .pancakeSwapPair();

        if (from == pancakeSwapPair) {
            buyTaxAmount = _updateTaxAmount(amount, buyTaxAmount, buyTax);
            return (amount * _getTotalTax(buyTax)) / 10000;
        }

        if (to == pancakeSwapPair) {
            sellTaxAmount = _updateTaxAmount(amount, sellTaxAmount, sellTax);
            return (amount * _getTotalTax(sellTax)) / 10000;
        }

        taxAmount = _updateTaxAmount(amount, taxAmount, tax);

        return (amount * _getTotalTax(tax)) / 10000;
    }

    function _isOnSwap(address from, address to)
        internal
        returns (bool isOnSwap, bool isSelling)
    {
        isOnSwap = false;
        isSelling = false;
        address pancakeSwapPair = IRematicAdmin(adminContract)
            .pancakeSwapPair();
        if (from == pancakeSwapPair || to == pancakeSwapPair) {
            isOnSwap = true;
            if (to == pancakeSwapPair) {
                isSelling = true;
            }
        }
    }

    function _checkAntiBot(address from, address to) internal {
        if (!_excludedFromAntiBot[from]) {
            if (timeBetweenSells > 0) {
                require(
                    block.timestamp - transactionLockTimeSell[from] >
                        timeBetweenSells,
                    "Wait before Sell!"
                );
                transactionLockTimeSell[from] = block.timestamp;
            }
        }

        if (!_excludedFromAntiBot[to]) {
            if (timeBetweenBuys > 0) {
                require(
                    block.timestamp - transactionLockTimeBuy[to] >
                        timeBetweenBuys,
                    "Wait before Buy!"
                );
                transactionLockTimeBuy[to] = block.timestamp;
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override antiWhale(from, to, amount) {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");

        if (!launched) {
            revert("Transaction is stopped");
        }

        if (amount == 0) {
            return;
        }

        if (stakingPoolsMap[from]) {
            super._transfer(from, to, amount);
            return;
        }

        if (stakingPoolsMap[to]) {
            super._transfer(from, to, amount);
            return;
        }

        if (IRematicAdmin(adminContract).isLiquidationProcessing()) {
            super._transfer(from, to, amount);
            return;
        }

        if (!tradeOn) {
            _basicTransfer(from, to, amount);
            return;
        }

        (bool isOnSwap, bool isSelling) = _isOnSwap(from, to);

        if (isOnSwap) {
            _checkAntiBot(from, to);
            uint256 txFee = _takeFee(from, to, amount);
            if (txFee > 0) super._transfer(from, address(this), txFee);
            amount = amount - txFee;
            _basicTransfer(from, to, amount);
            if (isSelling) {
                IRematicAdmin(adminContract)
                    .recordTransactionHistoryForHoldersPartition(
                        payable(from),
                        amount,
                        isSelling
                    );
            } else {
                IRematicAdmin(adminContract)
                    .recordTransactionHistoryForHoldersPartition(
                        payable(to),
                        amount,
                        isSelling
                    );
            }
        } else {
            uint256 txFee = _takeFee(from, to, amount);
            if (txFee > 0) super._transfer(from, address(this), txFee);
            amount = amount - txFee;
            _basicTransfer(from, to, amount);
        }

        if (balanceOf(address(this)) >= swapThreshold) {
            _startLiquidation();
        }
    }

    function transferTokenFromPool(address to, uint256 amount)
        external
        onlyFSPPool
        antiWhale(msg.sender, to, amount)
    {
        super._transfer(msg.sender, to, amount);
        IRematicAdmin(adminContract).mintDividendTrackerToken(to, amount);
    }

    function _updateDivBalances(address from, address to) internal {
        uint256 pollBalanceOfFrom = IFSPFactory(stakingContract)
            .totalDepositAmount(from);
        uint256 pollBalanceOfTo = IFSPFactory(stakingContract)
            .totalDepositAmount(to);
        IRematicAdmin(adminContract).setBalance(
            payable(from),
            balanceOf(from) + pollBalanceOfFrom
        );
        IRematicAdmin(adminContract).setBalance(
            payable(to),
            balanceOf(to) + pollBalanceOfTo
        );
    }

    function setAdminContractAdddress(address _address) external onlyOwner {
        require(
            _address != address(adminContract),
            "RFX: The adminContract already has that address"
        );
        adminContract = _address;
    }

    function setBurnWallet(address _address) external onlyOwner {
        require(
            _address != address(burnWallet),
            "RFX Admin: already same value"
        );
        burnWallet = _address;
    }

    function setStakingWallet(address _address) external onlyOwner {
        require(
            _address != address(stakingWallet),
            "RFX Admin: already same value"
        );
        stakingWallet = _address;
    }

    function totalCirculatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(burnWallet);
    }

    function isExcludedFromAntiwhale(address ac) external view returns (bool) {
        return _excludedFromAntiWhale[ac];
    }

    /**
     * @dev Returns the max transfer amount.
     */
    function _maxTransferAmount() internal view returns (uint256) {
        // we can either use a percentage of supply
        if (maxTransferAmountRate > 0) {
            return (totalSupply() * maxTransferAmountRate) / 10000;
        }
        // or we can just set an actual number
        return (totalSupply() * 100) / 10000;
    }

    function excludeFromFees(address account, bool excluded)
        external
        onlyOwner
    {
        require(
            _excludedFromFee[account] != excluded,
            "Rematic: Account is already the value of 'excluded'"
        );
        _excludedFromFee[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _excludedFromFee[account];
    }

    function withdrawToken(address token, address account) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(address(this), account, balance);
    }

    function widthrawBNB(address _to) external onlyOwner {
        (bool success, ) = address(_to).call{value: address(this).balance}(
            new bytes(0)
        );
        require(success, "Withdraw failed");
    }

    function excludeFromAntiwhale(address account, bool excluded)
        external
        onlyOwner
    {
        _excludedFromAntiWhale[account] = excluded;
    }

    function excludedFromAntiBot(address account, bool excluded)
        external
        onlyOwner
    {
        _excludedFromAntiBot[account] = excluded;
    }

    function isExcludedFromAntiBot(address ac) external view returns (bool) {
        return _excludedFromAntiBot[ac];
    }

    function changeTimeSells(uint256 _value) external onlyOwner {
        require(_value <= 60 * 60 * 60, "Max 1 hour");
        timeBetweenSells = _value;
    }

    function changeTimeBuys(uint256 _value) external onlyOwner {
        require(_value <= 60 * 60 * 60, "Max 1 hour");
        timeBetweenBuys = _value;
    }

    function setMaxTransfertAmountRate(uint256 value) external onlyOwner {
        require(value > 0, "fail");
        maxTransferAmountRate = value;
    }

    function setTradeOn(bool flag) external onlyOwner {
        require(tradeOn != flag, "Same value set already");
        tradeOn = flag;
    }

    function setLaunched(bool flag) external onlyOwner {
        require(launched != flag, "Same value set already");
        launched = flag;
    }

    function _startLiquidation() internal {
        // uint256 contractBalance = balanceOf(address(this));

        // send burnWallet
        super._transfer(
            address(this),
            burnWallet,
            buyTaxAmount.burn.add(sellTaxAmount.burn).add(taxAmount.burn)
        );

        // send stakingWallet
        super._transfer(
            address(this),
            stakingWallet,
            buyTaxAmount.stake.add(sellTaxAmount.stake).add(taxAmount.stake)
        );

        // send rest tax to admin to liquidate
        super._transfer(address(this), adminContract, balanceOf(address(this)));

        _resetTaxAmount();

        emit Liquidation(balanceOf(address(this)));
    }

    function SetSwapThreshold(uint256 _newThreshold) external onlyOwner {
        require(swapThreshold != _newThreshold, "Already Same value");
        swapThreshold = _newThreshold;
    }

    function addPool(address _pool) external onlyOwner {
        stakingPoolsMap[_pool] = true;
        _excludedFromAntiWhale[_pool] = true;
    }

    function removePool(address _pool) external onlyOwner {
        stakingPoolsMap[_pool] = false;
        _excludedFromAntiWhale[_pool] = false;
    }

    function setStakingContract(address _address) external onlyOwner {
        require(stakingContract != _address, "Same value already!");
        stakingContract = _address;
    }

    function _getTotalTax(Tax memory _tax)
        internal
        pure
        returns (uint256 totalTax)
    {
        {
            totalTax = _tax
                .burn
                .add(_tax.stake)
                .add(_tax.liquidity)
                .add(_tax.pension)
                .add(_tax.legal);
        }

        {
            totalTax = totalTax
                .add(_tax.team)
                .add(_tax.divtracker)
                .add(_tax.partition)
                .add(_tax.k401);
        }
    }

    function _updateTaxAmount(
        uint256 _transAmount,
        TaxAmount memory _taxAmount,
        Tax memory _tax
    ) internal pure returns (TaxAmount memory resultTaxAmount) {
        resultTaxAmount = _taxAmount;
        resultTaxAmount.stake = resultTaxAmount.stake.add(
            _transAmount.mul(_tax.stake).div(10000)
        );
        resultTaxAmount.burn = resultTaxAmount.burn.add(
            _transAmount.mul(_tax.burn).div(10000)
        );
        resultTaxAmount.liquidity = resultTaxAmount.liquidity.add(
            _transAmount.mul(_tax.liquidity).div(10000)
        );
        resultTaxAmount.pension = resultTaxAmount.pension.add(
            _transAmount.mul(_tax.pension).div(10000)
        );
        resultTaxAmount.team = resultTaxAmount.team.add(
            _transAmount.mul(_tax.team).div(10000)
        );
        resultTaxAmount.legal = resultTaxAmount.legal.add(
            _transAmount.mul(_tax.legal).div(10000)
        );
        resultTaxAmount.divtracker = resultTaxAmount.divtracker.add(
            _transAmount.mul(_tax.divtracker).div(10000)
        );
        resultTaxAmount.partition = resultTaxAmount.partition.add(
            _transAmount.mul(_tax.partition).div(10000)
        );
        resultTaxAmount.k401 = resultTaxAmount.k401.add(
            _transAmount.mul(_tax.k401).div(10000)
        );
    }

    function updateBuyTax(Tax memory _newTax) external onlyOwner {
        buyTax.stake = _newTax.stake;
        buyTax.burn = _newTax.burn;
        buyTax.liquidity = _newTax.liquidity;
        buyTax.pension = _newTax.pension;
        buyTax.legal = _newTax.legal;
        buyTax.team = _newTax.team;
        buyTax.divtracker = _newTax.divtracker;
        buyTax.partition = _newTax.partition;
        buyTax.k401 = _newTax.k401;
    }

    function updateSellTax(Tax memory _newTax) external onlyOwner {
        sellTax.stake = _newTax.stake;
        sellTax.burn = _newTax.burn;
        sellTax.liquidity = _newTax.liquidity;
        sellTax.pension = _newTax.pension;
        sellTax.legal = _newTax.legal;
        sellTax.team = _newTax.team;
        sellTax.divtracker = _newTax.divtracker;
        sellTax.partition = _newTax.partition;
        sellTax.k401 = _newTax.k401;
    }

    function updateTax(Tax memory _newTax) external onlyOwner {
        tax.stake = _newTax.stake;
        tax.burn = _newTax.burn;
        tax.liquidity = _newTax.liquidity;
        tax.pension = _newTax.pension;
        tax.legal = _newTax.legal;
        tax.team = _newTax.team;
        tax.divtracker = _newTax.divtracker;
        tax.partition = _newTax.partition;
        tax.k401 = _newTax.k401;
    }

    function _resetTaxAmount() internal {
        sellTaxAmount.stake = 0;
        sellTaxAmount.burn = 0;
        sellTaxAmount.liquidity = 0;
        sellTaxAmount.pension = 0;
        sellTaxAmount.legal = 0;
        sellTaxAmount.team = 0;
        sellTaxAmount.divtracker = 0;
        sellTaxAmount.partition = 0;
        sellTaxAmount.k401 = 0;

        buyTaxAmount.stake = 0;
        buyTaxAmount.burn = 0;
        buyTaxAmount.liquidity = 0;
        buyTaxAmount.pension = 0;
        buyTaxAmount.legal = 0;
        buyTaxAmount.team = 0;
        buyTaxAmount.divtracker = 0;
        buyTaxAmount.partition = 0;
        buyTaxAmount.k401 = 0;

        taxAmount.stake = 0;
        taxAmount.burn = 0;
        taxAmount.liquidity = 0;
        taxAmount.pension = 0;
        taxAmount.legal = 0;
        taxAmount.team = 0;
        taxAmount.divtracker = 0;
        taxAmount.partition = 0;
        taxAmount.k401 = 0;
    }
}