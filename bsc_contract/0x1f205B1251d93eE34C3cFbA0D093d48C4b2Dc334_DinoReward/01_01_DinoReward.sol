// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IERC20Reward {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IWETHReward {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address guy, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
    function allowance(address _owner, address spender)
    external
    view
    returns (uint256);
}

abstract contract ContextReward {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract OwnableReward is ContextReward {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2PairReward {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2FactoryReward {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Router01Reward {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02Reward is IUniswapV2Router01Reward {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20MetadataReward is IERC20Reward {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

contract ERC20Reward is ContextReward, IERC20Reward, IERC20MetadataReward {

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + (addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IDinoReward {
    function setShare(address,uint256) external;
}

contract DinoReward is OwnableReward, IDinoReward {
    address public tokenAddress;
    address public wethAddress;
    address public wbnbAddress;
    address public routerAddress;
    address public walletAutoDistributeAddress;
    address public defaultTokenReward;
    uint256 public lastResetAPR = 0;
    uint256 public loopInterest = 0;
    uint256 public APR = 0;
    bool public isCountAPRAYREnable = true;
    uint256 public totalClaimWeekly = 0;
    uint256 public totalReceiveWeekBNB = 0;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalClaimed;
    }

    bool public isFeeAutoDistributeEnable = true;
    bool public isFeeEnable = false;
    uint256 public percentGasDistibute = 10;
    uint256 public percentGasMultiplier = 10000;

    address[] public shareholders;
    mapping (address => uint256) public shareholderIndexes;
    mapping (address => uint256) public shareholderClaims;
    mapping (address => bool) public isExcludeFromReward;

    mapping (address => Share) public shares;
    mapping (address => address) public holderPreferenceDistributeToToken;

    mapping (address => uint256) public totalDistributeToToken;
    uint256 public totalDistributeToWeth;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10**36;

    uint256 public currentIndex;

    uint256 public minimumPeriod = 1 seconds;
    uint256 public minimumDistribution = 1 * (10**18);
    uint256 public minimumGasDistribution = 750000;
    uint256 public percentTaxDenominator = 10000;

    uint256 public indexCurrentShare = 0;

    uint256 public batchClaimLoop = 0;

    uint256 public percentForFarming = 0;
    uint256 public percentForStaking = 0;
    uint256 public percentForReferral = 0;
    uint256 public percentForEarn = 100;

    address public stakingAddress;
    address public farmingAddress;
    address public referralAddress;

    mapping (address => bool) public isCanSetShares;

    event Deposit(address account, uint256 amount);
    event Distribute(address account, uint256 amount);
    event UpdateDistributionPercentage(uint256 earn, uint256 farming, uint256 staking, uint256 referral);
    event SetFarmingStakingAddress(address farming, address staking, address referral);

    modifier onlyToken() {
        require(_msgSender()==tokenAddress);
        _;
    }

    modifier onlyCanSetShare() {
        require(isCanSetShares[_msgSender()] || _msgSender() == tokenAddress,"Unauthorize for Set Share");
        _;
    }

    constructor(address _tokenAddress, address _defaultTokenReward) OwnableReward() {
        if(block.chainid == 97) routerAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        else if(block.chainid == 56) routerAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        else routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

        tokenAddress = _tokenAddress;
        defaultTokenReward = _defaultTokenReward;

        IUniswapV2Router02Reward router = IUniswapV2Router02Reward(routerAddress);
        wethAddress = router.WETH();
        wbnbAddress = router.WETH();
        walletAutoDistributeAddress = 0x0ab478ccB5effCc2510326257Ce0525cD91FcfB1;
        lastResetAPR = block.timestamp;

        isCanSetShares[tokenAddress] = true;
        setExcludeFromReward(tokenAddress,true);
        setExcludeFromReward(address(this),true);
    }

    receive() external payable {
        deposit();
    }

    function setExcludeFromReward(address _address, bool _state) public onlyOwner {
        isExcludeFromReward[_address] = _state;
    }

    function setCanSetShares(address _address, bool _state) external onlyOwner {
        isCanSetShares[_address] = _state;
    }

    /** Set Shareholder */
    function setShare(address account,uint256 amount) external override onlyCanSetShare {
        if(!isExcludeFromReward[account]){
            bool isShouldClaim = shouldClaim(account);
            if(shares[account].amount > 0 && isShouldClaim && amount > 0){
                _claimToToken(account,defaultTokenReward);
            }
            if(amount > 0 && shares[account].amount == 0){
                addShareholder(account);
            }else if(amount == 0 && shares[account].amount > 0){
                removeShareholder(account);
            }

            totalShares = totalShares - shares[account].amount + amount;
            shares[account].amount = amount;
            shares[account].totalExcluded = getCumulativeDividend(shares[account].amount);
        }
    }

    function deposit() public payable {
        uint256 amountDeposit  = msg.value;
        uint256 amountForFarming = 0;
        uint256 amountForStaking = 0;
        uint256 amountForReferral = 0;
        bool success;
        if(percentForFarming > 0 && stakingAddress != address(0)) {
            amountForFarming = amountDeposit * percentForFarming / 100;
            (success,) = address(farmingAddress).call{value: amountForFarming}("");
        }
        if(percentForStaking > 0 && farmingAddress != address(0)) {
            amountForStaking = amountDeposit * percentForStaking / 100;
            (success,) = address(stakingAddress).call{value: amountForStaking}("");
        }
        if(percentForReferral > 0 && referralAddress != address(0)) {
            amountForReferral = amountDeposit * percentForReferral / 100;
            (success,) = address(referralAddress).call{value: amountForReferral}("");
        }

        uint256 amountDividen = amountDeposit - amountForFarming - amountForStaking - amountForReferral;
        IWETHReward(wbnbAddress).deposit{value:amountDividen}();
        totalDividends = totalDividends + amountDividen;
        if(totalShares > 0 && amountDividen > 0) dividendsPerShare = dividendsPerShare + (dividendsPerShareAccuracyFactor * amountDividen / totalShares);
        loopInterest = loopInterest + 1;
        if(isCountAPRAYREnable) countAPRAPY(msg.value);
        batchClaimed();
        emit Deposit(msg.sender,msg.value);
    }

    function setPercentDistribution(uint256 _percentEarn, uint256 _percentFarming, uint256 _percentStaking, uint256 _percentReferral) external onlyOwner {
        percentForEarn = _percentEarn;
        percentForFarming = _percentFarming;
        percentForStaking = _percentStaking;
        percentForReferral = _percentReferral;
        emit UpdateDistributionPercentage(_percentEarn,_percentFarming,_percentStaking,_percentReferral);
        require(percentForStaking+percentForFarming+percentForEarn+percentForReferral == 100,"Distribution Should 100%");
    }

    function setFarmingStakingAddress(address _farming, address _staking, address _referral) external onlyOwner {
        stakingAddress = _staking;
        farmingAddress = _farming;
        referralAddress = _referral;
        emit SetFarmingStakingAddress(_farming,_staking,_referral);
    }

    function countAPRAPY(uint256 amount) internal {
        if(block.timestamp - (lastResetAPR) >= 7 days) {
            totalReceiveWeekBNB = 0;
            totalClaimWeekly = 0;
            loopInterest = 1;
            lastResetAPR = block.timestamp;
        }

        totalReceiveWeekBNB = totalReceiveWeekBNB + amount;

        unchecked {
            uint year = 365;
            uint day = 7;
            APR = totalReceiveWeekBNB * (percentTaxDenominator) / (totalShares) * (year / (day)) * (100) / (percentTaxDenominator);
        }
    }

    function getCurrentBalance() public view returns(uint256){
        return IWETHReward(wbnbAddress).balanceOf(address(this));
    }

    /** Distributing Dividen */
    function distributeDividend() external {
        // Distribute Dividen
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < minimumGasDistribution && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividendShareholder(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft / (gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;

        }
    }

    function distributeDividendShareholder(address account) internal {
        if(shouldClaim(account)) {
            if(holderPreferenceDistributeToToken[account] == address(0))
                _claimToToken(account,defaultTokenReward);
            else if(holderPreferenceDistributeToToken[account] == wethAddress)
                _claimToWeth(account);
            else
                _claimToToken(account,holderPreferenceDistributeToToken[account]);
        }
    }

    function shouldDistribute(address account) internal view returns(bool) {
        return shareholderClaims[account] + minimumPeriod < block.timestamp
        && dividendOf(account) > minimumDistribution;
    }

    /** Get dividend of account */
    function dividendOf(address account) public view returns (uint256) {

        if(shares[account].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividend(shares[account].amount);
        uint256 shareholderTotalExcluded = shares[account].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends-(shareholderTotalExcluded);
    }

    /** Get cumulative dividend */
    function getCumulativeDividend(uint256 share) internal view returns (uint256) {
        return share*(dividendsPerShare)/(dividendsPerShareAccuracyFactor);
    }

    /** Claim to Dino */
    function claim(address account) external{
        _claimToToken(account,defaultTokenReward);
    }

    /** Claim to other token */
    function claimTo(address account, address targetToken) external {
        require(targetToken != wethAddress,"DinoReward: Wrong function if you want to claim to WETH");
        _claimToToken(account,targetToken);
    }

    /** Claim to weth */
    function claimToWeth(address account) external{
        _claimToWeth(account);
    }

    function getPairAddress(address token) public view returns(address){
        IUniswapV2Router02Reward router = IUniswapV2Router02Reward(routerAddress);
        IUniswapV2FactoryReward factory = IUniswapV2FactoryReward(router.factory());
        address pair = factory.getPair(tokenAddress,token);
        return pair;
    }

    function shouldClaim(address account) internal view returns(bool) {
        if(getCurrentBalance() == 0) return false;
        if(shares[account].totalClaimed >= shares[account].totalExcluded) return false;
        return true;
    }

    function batchClaimed() public {
        if(batchClaimLoop > 0){
            uint maxLoop = shareholders.length > batchClaimLoop ? batchClaimLoop : shareholders.length;
            uint startLoop = indexCurrentShare;
            for(uint i=0;i<maxLoop;i++){
                if(startLoop < shareholders.length){
                    _claimToToken(shareholders[startLoop],defaultTokenReward);
                    startLoop = startLoop+1;
                    indexCurrentShare = indexCurrentShare+1;
                }
            }
            if(indexCurrentShare >= shareholders.length) indexCurrentShare = 0;
        }
    }

    function setBatchClaimLoop(uint256 _loop) external onlyOwner {
        batchClaimLoop = _loop;
    }

    function claimFarmingReward(address pairAddress) external onlyCanSetShare {
        uint256 amount = IERC20Reward(tokenAddress).balanceOf(pairAddress);
        if(shares[pairAddress].amount > 0){
            _claimToWeth(pairAddress);
        }
        // If amount greater than 0 and current share is zero, then add as shareholder
        // if amount is zero and current account is shareholder, then remove it

        if(amount > 0 && shares[pairAddress].amount == 0){
            addShareholder(pairAddress);
        }else if(amount == 0 && shares[pairAddress].amount > 0){
            removeShareholder(pairAddress);
        }

        totalShares = totalShares - (shares[pairAddress].amount) + (amount);
        shares[pairAddress].amount = amount;
        shares[pairAddress].totalExcluded = getCumulativeDividend(shares[pairAddress].amount);

    }

    function getFee(uint256 amountReward) internal pure returns(uint256){
        return amountReward;
    }

    /** execute claim to token */
    function _claimToToken(address account, address targetToken) internal {
        IUniswapV2Router02Reward router = IUniswapV2Router02Reward(routerAddress);
        uint256 amount = dividendOf(account);
        uint256 amountAfterFee = getFee(amount);
        if(amountAfterFee > 0){

            if(targetToken == wbnbAddress){
                IWETHReward(wbnbAddress).withdraw(amountAfterFee);
                payable(account).transfer(amountAfterFee);
            } else {
                if(wbnbAddress != router.WETH()){
                    IWETHReward(wbnbAddress).withdraw(amountAfterFee);
                    IWETHReward(router.WETH()).deposit{value:amountAfterFee}();
                }
                address[] memory path = new address[](2);
                path[0] = router.WETH();
                path[1] = targetToken;
                IWETHReward(router.WETH()).approve(routerAddress,amountAfterFee);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountAfterFee,
                    0,
                    path,
                    account,
                    block.timestamp
                );
            }
            totalDistributeToToken[targetToken] = totalDistributeToToken[targetToken] + (amount);
            setClaimed(account,amount);
        }
    }


    /** execute claim to weth */
    function _claimToWeth(address account) internal {
        uint256 amount = dividendOf(account);
        uint256 amountAfterFee = getFee(amount);
        if(address(this).balance >= amountAfterFee && amountAfterFee > 0){
            IWETHReward(wbnbAddress).withdraw(amountAfterFee);
            payable(account).transfer(amountAfterFee);
            totalDistributeToWeth = totalDistributeToWeth+(amount);
            setClaimed(account,amount);
        }
    }

    /** get total claim token in weth */
    function claimTotalOf(address account) external view returns(uint256){
        return shares[account].totalClaimed;
    }

    /** Set claimed state */
    function setClaimed(address account, uint256 amount) internal {
        shareholderClaims[account] = block.timestamp;
        shares[account].totalClaimed = shares[account].totalClaimed+(amount);
        shares[account].totalExcluded = getCumulativeDividend(shares[account].amount);
        totalDistributed = totalDistributed+(amount);
        // calculateDividenPerShare();
        emit Distribute(account, amount);
    }

    /** Adding share holder */
    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    /** Remove share holder */
    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

    function setPreferenceDistributeTo(address account, address targetToken) external {
        holderPreferenceDistributeToToken[account] = targetToken;
    }

    function setWbnbAddress(address _wbnb) external onlyOwner {
        wbnbAddress = _wbnb;
    }

    function setDefaultReflectionToken(address _address) external onlyOwner {
        defaultTokenReward = _address;
    }

    /** Setting Minimum Distribution */
    function setMinimumDistribution(uint256 timePeriod,uint256 minAmount) external onlyOwner {
        minimumPeriod = timePeriod;
        minimumDistribution = minAmount;
    }

    /** Setting Minimum Distribution Reward */
    function setDistributionGas(uint256 gas) external onlyOwner {
        require(gas <= 750000);
        minimumGasDistribution = gas;
    }

    function getTokenFromContract(address _tokenAddress, address to, uint256 amount) external onlyOwner {
        try IERC20Reward(_tokenAddress).approve(to, amount) {} catch {}
        try IERC20Reward(_tokenAddress).transfer(to,amount) {} catch {}
    }

    function estimationReward(address account, address token) external view returns(uint[] memory amounts){
        uint256 dividend = dividendOf(account);
        IUniswapV2Router02Reward router = IUniswapV2Router02Reward(routerAddress);
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token;
        return router.getAmountsOut(dividend,path);

    }

    function setAutoDistribute(bool _isEnable, uint256 _percentGasDistribute) external onlyOwner {
        isFeeAutoDistributeEnable = _isEnable;
        percentGasDistibute = _percentGasDistribute;
    }

    function setWalletAutoDistributeAddress(address _address) external onlyOwner {
        walletAutoDistributeAddress = _address;
    }

    function setIsFeeEnable(bool _state) external onlyOwner {
        isFeeEnable = _state;
    }

    function setCountAPRAPY(bool state) external onlyOwner {
        isCountAPRAYREnable = state;
    }

    function setIndexCurrentShare(uint _index) external onlyOwner {
        indexCurrentShare = _index;
    }
}