/**
 *Submitted for verification at BscScan.com on 2023-03-28
*/

// SPDX-License-Identifier:MIT
pragma solidity ^0.8.10;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// Dex Factory contract interface
interface IDexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

// Dex Router contract interface
interface IDexRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = payable(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Test123 is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private isExcludedFromFee;
    mapping(address => bool) private isExcludedFromMaxTxn;
    mapping(address => bool) private isExcludedFromMaxHolding;

    string private _name = "Test123";
    string private _symbol = "Test123";
    uint8 private _decimals = 9;
    uint256 private _totalSupply = 100_000_000 * 1e9;

    address private constant DEAD = address(0xdead);
    address private constant ZERO = address(0);
    IDexRouter public dexRouter;
    address private dexPair;
    address public marketingWallet;
    address private liquidityReceiverWallet;
    address private devWallet;
    address public VaultWallet;

    uint256 private minTokenToSwap = _totalSupply.mul(3).div(1000); // this amount will trigger swap and distribute
    uint256 public maxHoldLimit = _totalSupply.div(50); // this is the max wallet holding limit
    uint256 public maxTxnLimit = _totalSupply.div(50); // this is the max transaction limit
    uint256 public maxBuyLimit = _totalSupply.div(50); // this is the max buy limit
    uint256 public maxSellLimit = _totalSupply.div(50); // this is the max sell limit
    uint256 private botFee = 99;
    uint256 private percentDivider = 100;
    uint256 private snipingTime = 36 seconds;
    uint256 private launchedAt;

    bool public distributeAndLiquifyStatus; // should be true to turn on to liquidate the pool
    bool private feesStatus = true; // enable by default
    bool public trading; // once enable can't be disable afterwards

    uint256 private marketingFeeOnBuying = 0; // this fee will be added to the marketing address
    uint256 private liquidityFeeOnBuying = 0; // this fee will be added to the liquidity
    uint256 private devFeeOnBuying = 20; // this fee will be added to the dev address
    uint256 private VaultFeeOnBuying = 0; // this fee will be added to the Vault address

    uint256 private marketingFeeOnSelling = 45; // this fee will be added to the marketing 
    uint256 private liquidityFeeOnSelling = 2; // this fee will be added to the liquidityaddress
    uint256 private devFeeOnSelling = 8; // this fee will be added to the dev address
    uint256 private VaultFeeOnSelling = 5; // this fee will be added to the Vault address

    uint256 marketingFeeCounter = 0;
    uint256 liquidityFeeCounter = 0;
    uint256 devFeeCounter = 0;
    uint256 VaultFeeCounter = 0;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor() {
        _balances[owner()] = _totalSupply;
        liquidityReceiverWallet = msg.sender;
        marketingWallet = address(0xAe964e53AaE7F00FEB37988586F4C07A67806AcA);
        devWallet = address(0x070105F15D7344eDA4D4EB0e5cAa1dAea1C1027E);
        VaultWallet = address(0x6fAC7bda4b2Cc0131865390874CA973723234C16);

        IDexRouter _dexRouter = IDexRouter(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        // Create a dex pair for this new ERC20
        address _dexPair = IDexFactory(_dexRouter.factory()).createPair(
            address(this),
            _dexRouter.WETH()
        );
        dexPair = _dexPair;

        // set the rest of the contract variables
        dexRouter = _dexRouter;

        //exclude owner and this contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[address(dexRouter)] = true;
        isExcludedFromFee[marketingWallet] = true;
        isExcludedFromFee[devWallet] = true;
        isExcludedFromFee[VaultWallet] = true;

        //exclude owner and this contract from max Txn
        isExcludedFromMaxTxn[owner()] = true;
        isExcludedFromMaxTxn[address(this)] = true;
        isExcludedFromMaxTxn[address(dexRouter)] = true;
        isExcludedFromMaxTxn[marketingWallet] = true;
        isExcludedFromMaxTxn[devWallet] = true;
        isExcludedFromMaxTxn[VaultWallet] = true;

        //exclude owner and this contract from max hold limit
        isExcludedFromMaxHolding[owner()] = true;
        isExcludedFromMaxHolding[address(this)] = true;
        isExcludedFromMaxHolding[address(dexRouter)] = true;
        isExcludedFromMaxHolding[dexPair] = true;
        isExcludedFromMaxHolding[marketingWallet] = true;
        isExcludedFromMaxHolding[devWallet] = true;
        isExcludedFromMaxHolding[VaultWallet] = true;

        emit Transfer(address(0), owner(), _totalSupply);
    }

    //to receive ETH from dexRouter when swapping
    receive() external payable {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "VaultGPT: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "VaultGPT: decreased allowance or below zero"
            )
        );
        return true;
    }

    function includeOrExcludeFromFee(
        address account,
        bool value
    ) external onlyOwner {
        isExcludedFromFee[account] = value;
    }

    function includeOrExcludeFromMaxTxn(
        address account,
        bool value
    ) external onlyOwner {
        isExcludedFromMaxTxn[account] = value;
    }

    function includeOrExcludeFromMaxHolding(
        address account,
        bool value
    ) external onlyOwner {
        isExcludedFromMaxHolding[account] = value;
    }

    function setMinTokenToSwap(uint256 _amount) external onlyOwner {
        require(_amount > 0, "VaultGPT: can't be 0");
        minTokenToSwap = _amount;
    }

    function setMaxHoldLimit(uint256 _amount) external onlyOwner {
        require(
            _amount >= _totalSupply.div(100_00),
            "VaultGPT: should be greater than 0.01%"
        );
        maxHoldLimit = _amount;
    }

    function setMaxTxnLimit(uint256 _amount) external onlyOwner {
        require(
            _amount >= _totalSupply / 100_00,
            "VaultGPT: should be greater than 0.01%"
        );
        maxTxnLimit = _amount;
    }

    function setMaxBuyLimit(uint256 _amount) external onlyOwner {
        require(
            _amount >= _totalSupply / 100_00,
            "VaultGPT: should be greater than 0.01%"
        );
        maxBuyLimit = _amount;
    }

    function setMaxSellLimit(uint256 _amount) external onlyOwner {
        require(
            _amount >= _totalSupply / 100_00,
            "VaultGPT: should be greater than 0.01%"
        );
        maxSellLimit = _amount;
    }

    function setBuyFeePercent(
        uint256 _marketingFee,
        uint256 _lpFee,
        uint256 _devFee,
        uint256 _VaultFee
    ) external onlyOwner {
        liquidityFeeOnBuying = _lpFee;
        marketingFeeOnBuying = _marketingFee;
        devFeeOnBuying = _devFee;
        VaultFeeOnBuying = _VaultFee;
        require(
            _lpFee.add(_devFee).add(_marketingFee).add(_VaultFee) <=
                percentDivider.mul(20).div(100),
            "VaultGPT: can't be more than 20%"
        );
    }

    function setSellFeePercent(
        uint256 _marketingFee,
        uint256 _lpFee,
        uint256 _devFee,
        uint256 _VaultFee
    ) external onlyOwner {
        marketingFeeOnSelling = _marketingFee;
        liquidityFeeOnSelling = _lpFee;
        devFeeOnSelling = _devFee;
        VaultFeeOnSelling = _VaultFee;
        require(
            _lpFee.add(_devFee).add(_marketingFee).add(_VaultFee) <=
                percentDivider.mul(99).div(100),
            "VaultGPT: can't be more than 99%" // to shake bots, normal tax will be 5%
        );
    }

    function setDistributionStatus(bool _value) public onlyOwner {
        distributeAndLiquifyStatus = _value;
    }

    function enableOrDisableFees(bool _value) external onlyOwner {
        feesStatus = _value;
    }

    function removeStuckEth(address _receiver) public onlyOwner {
        payable(_receiver).transfer(address(this).balance);
    }

    function updateAddresses(
        address _marketingWallet,
        address _devWallet,
        address _VaultWallet,
        address _liquidityReceiverWallet
    ) external onlyOwner {
        marketingWallet = _marketingWallet;
        devWallet = _devWallet;
        VaultWallet = _VaultWallet;
        liquidityReceiverWallet = _liquidityReceiverWallet;
    }

    function enableTrading() external onlyOwner {
        require(!trading, "VaultGPT: already enabled");
        trading = true;
        feesStatus = true;
        distributeAndLiquifyStatus = true;
        launchedAt = block.timestamp;
    }

    function totalBuyFeePerTx(uint256 amount) public view returns (uint256) {
        uint256 fee = amount
            .mul(
                marketingFeeOnBuying
                    .add(liquidityFeeOnBuying)
                    .add(devFeeOnBuying)
                    .add(VaultFeeOnBuying)
            )
            .div(percentDivider);
        return fee;
    }

    function totalSellFeePerTx(uint256 amount) public view returns (uint256) {
        uint256 fee = amount
            .mul(
                marketingFeeOnSelling
                    .add(liquidityFeeOnSelling)
                    .add(devFeeOnSelling)
                    .add(VaultFeeOnSelling)
            )
            .div(percentDivider);
        return fee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "VaultGPT: approve from the zero address");
        require(spender != address(0), "VaultGPT: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "VaultGPT: transfer from the zero address");
        require(to != address(0), "VaultGPT: transfer to the zero address");
        require(amount > 0, "VaultGPT: Amount must be greater than zero");

        if (!isExcludedFromMaxTxn[from] && !isExcludedFromMaxTxn[to]) {
            require(amount <= maxTxnLimit, "VaultGPT: max txn limit exceeds");

            // trading disable till launch
            if (!trading) {
                require(
                    dexPair != from && dexPair != to,
                    "VaultGPT: trading is disable"
                );
            }
            // antibot
            if (
                block.timestamp < launchedAt + snipingTime &&
                from != address(dexRouter)
            ) {
                uint256 allFee = amount.mul(botFee).div(percentDivider);
                uint256 tTransferAmount = amount.sub(allFee);
                devFeeCounter += allFee;
                _balances[from] = _balances[from].sub(
                    amount,
                    "VaultGPT: insufficient balance"
                );
                _balances[to] = _balances[to].add(tTransferAmount);

                emit Transfer(from, to, tTransferAmount);
                takeTokenFee(from, allFee);
                return;
            }
        }

        if (!isExcludedFromMaxHolding[to]) {
            require(
                balanceOf(to).add(amount) <= maxHoldLimit,
                "VaultGPT: max hold limit exceeds"
            );
        }

        // swap and liquify
        distributeAndLiquify(from, to);

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to isExcludedFromFee account then remove the fee
        if (isExcludedFromFee[from] || isExcludedFromFee[to] || !feesStatus) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (dexPair == sender && takeFee) {
            require(amount <= maxBuyLimit, "Buy limit exceeds");
            uint256 allFee = totalBuyFeePerTx(amount);
            uint256 tTransferAmount = amount.sub(allFee);
            _balances[sender] = _balances[sender].sub(
                amount,
                "VaultGPT: insufficient balance"
            );
            _balances[recipient] = _balances[recipient].add(tTransferAmount);

            emit Transfer(sender, recipient, tTransferAmount);
            takeTokenFee(sender, allFee);
            setFeeCountersOnBuying(amount);
        } else if (dexPair == recipient && takeFee) {
            require(amount <= maxSellLimit, "Buy limit exceeds");
            uint256 allFee = totalSellFeePerTx(amount);
            uint256 tTransferAmount = amount.sub(allFee);
            _balances[sender] = _balances[sender].sub(
                amount,
                "VaultGPT: insufficient balance"
            );
            _balances[recipient] = _balances[recipient].add(tTransferAmount);

            emit Transfer(sender, recipient, tTransferAmount);
            takeTokenFee(sender, allFee);
            setFeeCountersOnSelling(amount);
        } else {
            _balances[sender] = _balances[sender].sub(
                amount,
                "VaultGPT: insufficient balance"
            );
            _balances[recipient] = _balances[recipient].add(amount);

            emit Transfer(sender, recipient, amount);
        }
    }

    function takeTokenFee(address sender, uint256 amount) private {
        _balances[address(this)] = _balances[address(this)].add(amount);

        emit Transfer(sender, address(this), amount);
    }

    function setFeeCountersOnBuying(uint256 amount) private {
        liquidityFeeCounter += amount.mul(liquidityFeeOnBuying).div(
            percentDivider
        );
        marketingFeeCounter += amount.mul(marketingFeeOnBuying).div(
            percentDivider
        );
        devFeeCounter += amount.mul(devFeeOnBuying).div(percentDivider);
        VaultFeeCounter += amount.mul(VaultFeeOnBuying).div(percentDivider);
    }

    function setFeeCountersOnSelling(uint256 amount) private {
        liquidityFeeCounter += amount.mul(liquidityFeeOnSelling).div(
            percentDivider
        );
        marketingFeeCounter += amount.mul(marketingFeeOnSelling).div(
            percentDivider
        );
        devFeeCounter += amount.mul(devFeeOnSelling).div(percentDivider);
        VaultFeeCounter += amount.mul(VaultFeeOnSelling).div(percentDivider);
    }

    function distributeAndLiquify(address from, address to) private {
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is Dex pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool shouldSell = contractTokenBalance >= minTokenToSwap;

        if (
            shouldSell &&
            from != dexPair &&
            distributeAndLiquifyStatus &&
            !(from == address(this) && to == address(dexPair)) // swap 1 time
        ) {
            // approve contract
            _approve(address(this), address(dexRouter), contractTokenBalance);

            uint256 halfLiquidity = liquidityFeeCounter.div(2);
            uint256 otherHalfLiquidity = liquidityFeeCounter.sub(halfLiquidity);

            uint256 tokenAmountToBeSwapped = contractTokenBalance.sub(
                otherHalfLiquidity
            );

            uint256 balanceBefore = address(this).balance;

            // now is to lock into liquidty pool
            Utils.swapTokensForEth(address(dexRouter), tokenAmountToBeSwapped);

            uint256 deltaBalance = address(this).balance.sub(balanceBefore);
            uint256 ethToBeAddedToLiquidity = deltaBalance
                .mul(halfLiquidity)
                .div(tokenAmountToBeSwapped);
            uint256 ethFormarketing = deltaBalance.mul(marketingFeeCounter).div(
                tokenAmountToBeSwapped
            );
            uint256 ethForDev = deltaBalance.mul(devFeeCounter).div(
                tokenAmountToBeSwapped
            );
            uint256 ethForVault = deltaBalance
                .sub(ethToBeAddedToLiquidity)
                .sub(ethForDev)
                .sub(ethFormarketing);

            // add liquidity to Dex
            if (ethToBeAddedToLiquidity > 0) {
                Utils.addLiquidity(
                    address(dexRouter),
                    liquidityReceiverWallet,
                    otherHalfLiquidity,
                    ethToBeAddedToLiquidity
                );

                emit SwapAndLiquify(
                    halfLiquidity,
                    ethToBeAddedToLiquidity,
                    otherHalfLiquidity
                );
            }

            // sending eth to marketing wallet
            if (ethFormarketing > 0)
                payable(marketingWallet).transfer(ethFormarketing);

            // sending eth to development wallet
            if (ethForDev > 0) payable(devWallet).transfer(ethForDev);

            // sending eth to development wallet
            if (ethForVault > 0) payable(VaultWallet).transfer(ethForVault);

            // Reset all fee counters
            liquidityFeeCounter = 0;
            marketingFeeCounter = 0;
            devFeeCounter = 0;
            VaultFeeCounter = 0;
        }
    }
}

// Library for doing a swap on Dex
library Utils {
    using SafeMath for uint256;

    function swapTokensForEth(
        address routerAddress,
        uint256 tokenAmount
    ) internal {
        IDexRouter dexRouter = IDexRouter(routerAddress);

        // generate the Dex pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        // make the swap
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 300
        );
    }

    function addLiquidity(
        address routerAddress,
        address owner,
        uint256 tokenAmount,
        uint256 ethAmount
    ) internal {
        IDexRouter dexRouter = IDexRouter(routerAddress);

        // add the liquidity
        dexRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner,
            block.timestamp + 300
        );
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}