/**
 *Submitted for verification at BscScan.com on 2023-03-24
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
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

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
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
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
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
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
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
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
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
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
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
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
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

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
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

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

}

contract PigVault is ERC20, ERC20Burnable, Ownable,ReentrancyGuard {
    address public marketingWallet;
    uint256 public buyMarketingFee = 0;
    uint256 public sellMarketingFee = 0;
    uint256 public transferMarketingFee = 0;


    IUniswapV2Router01 public pancakeswapV2Router;
    address public pancakeswapswapV2Pair;

    address public constant OWNER_ADDRESS = 0x8408D69Bd878542c79D6feFa5B4dc88C2aca1e1C;
    address public constant TEAM_ADDRESS = 0x938604703BE95Ae784C295419a48E021A4924188;
    address public constant FAIRLAUNCH_ADDRESS = 0x2197dDee6340C76CA1C4285a8F6Ddc2173CeE237;
    address public constant LIQUIDITY_ADDRESS = 0x95b213e7B03608F3c54226eE42DA91f0C99329B9;
    address public constant FEATURES_ADDRESS = 0x5315E51Ac1292B604c14b893C11E9F030068Ce9b;


    mapping (address => bool) public _isExcludedFromFee;

    event MarketingFeesSet(uint256 buy,uint256 sell,uint256 transfer);
    event NewMarketingAddress(address newAddress);
    event NewPancakePairAddress(address newAddress);
    event MarketingFeesSwappedToBNB(uint256 initialBalance,uint256 bnbAmount,address marketingWallet);
    event SetExcludeAddress(address userAddress, bool status);
    event SwapTokensForBNB(uint256 amountIn,address[] path);
    event SwapActivated(bool status);
    event TokenRemoved(address tokenAddress,address toAddress, uint256 amount);
    event BnbRemoved(address toAddress, uint256 amount);

    /**

        @dev Constructor function for PigVault ERC20 token.
        Initializes the contract by minting 100,000,000 PigVault tokens to defined address and setting the marketing wallet address.
        Creates a UniswapV2 pair for PigVault and WETH using the UniswapV2Router01 contract address.
        The contract owner and the contract address are excluded from fee.
    */
    constructor(
    ) ERC20("PigVault", "PGT") {
        _mint(OWNER_ADDRESS, 20000000 * 10 ** decimals()); //20%
        _mint(TEAM_ADDRESS, 10000000 * 10 ** decimals()); //10%
        _mint(FAIRLAUNCH_ADDRESS, 30000000 * 10 ** decimals()); //30%
        _mint(LIQUIDITY_ADDRESS, 15000000 * 10 ** decimals()); //15%
        _mint(FEATURES_ADDRESS, 25000000 * 10 ** decimals()); //25%
        marketingWallet = address(0xd6851c5118880267648A51d544C7C42932697E4d);

        // Testnet : 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // Mainnet : 0x10ED43C718714eb63d5aA57B78B54704E256024E
        // testnetpswapkiemtieonline: 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        IUniswapV2Router01 _uniswapV2Router = IUniswapV2Router01(0x10ED43C718714eb63d5aA57B78B54704E256024E);
  
        pancakeswapswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        pancakeswapV2Router = _uniswapV2Router;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;

        emit MarketingFeesSet(buyMarketingFee,sellMarketingFee,transferMarketingFee);
        emit NewMarketingAddress(marketingWallet);
        emit NewPancakePairAddress(pancakeswapswapV2Pair);
    }

    /**
        @dev Sets the marketing fees for buy, sell, and transfer transactions.
        @param _buyFee The buy fee percentage to set, must be less than or equal to 25%.
        @param _sellFee The sell fee percentage to set, must be less than or equal to 25%.
        @param _transferFee The transfer fee percentage to set, must be less than or equal to 25%.
        Requirements:
            .Only the owner can call this function.
            .The _buy fee percentage must be less than or equal to 25%.
            .The _sell fee percentage must be less than or equal to 25%.
            .The _transfer fee percentage must be less than or equal to 25%.
        Effects:
            .Sets the buyMarketingFee, sellMarketingFee, and transferMarketingFee variables.
    */
    function setMarketingFee(uint256 _buyFee,uint256 _sellFee,uint256 _transferFee) external onlyOwner {
        require(_buyFee <= 25, "Buy Fee must be less than or equal to 25%");
        require(_sellFee <= 25, "Sell Fee must be less than or equal to 25%");
        require(_transferFee <= 25, "Transfer Fee must be less than or equal to 25%");

        buyMarketingFee = _buyFee;
        sellMarketingFee = _sellFee;
        transferMarketingFee = _transferFee;

        emit MarketingFeesSet(buyMarketingFee,sellMarketingFee,transferMarketingFee);
    }

    /**

        @dev Internal function that transfers tokens from sender to recipient and applies marketing fees.
        @param sender The address sending the tokens.
        @param recipient The address receiving the tokens.
        @param amount The amount of tokens being transferred.
    */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount>0,"ERC20: amount must ne greater than 0");
        uint256 fee;
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            super._transfer(sender, recipient, amount);
        }else{
            // Buy
            if(buyMarketingFee>0 && sender != owner() && recipient != owner() && sender == pancakeswapswapV2Pair){
                fee = (amount * (buyMarketingFee)) / (100);
            }
            // Sell
            if(sellMarketingFee>0 && sender != owner() && recipient != owner() && recipient == pancakeswapswapV2Pair){
                fee = (amount * (sellMarketingFee)) / (100);
            }
            // Transfer
            if(transferMarketingFee>0 && sender != owner() && recipient != owner()){
                fee = (amount * (transferMarketingFee)) / (100);
            }

            uint256 remainingAmount = amount - (fee);
            super._transfer(sender, recipient, remainingAmount);
            if(fee>0){
                super._transfer(sender, address(this), fee);
            }
        }
    }


    /**
    @dev Swaps the marketing fees in PGT to BNB and transfers to the marketing wallet.
    Requirements:
        .The contract must have sufficient PGT balance to perform the swap.
    Effects:
        .Transfers the swapped BNB to the marketing wallet.
    */
    function swapMarketingFeesToBNB(uint256 _amount) private {
        // Get the contract's PGT balance
        uint256 initialBalance = _amount;

        // Swap the PGT to BNB using the PancakeSwap router
        address[] memory path = new address[](2);
        path[0] = address(this); // PGT token
        path[1] = pancakeswapV2Router.WETH();

        // Approve the PancakeSwap router to spend PGT tokens
        _approve(address(this), address(pancakeswapV2Router), initialBalance);

        // Perform the swap and get the BNB amount received
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            initialBalance,
            0.001 ether,
            path,
            address(this),
            block.timestamp
        );

        uint256 bnbAmount = address(this).balance;

        if (bnbAmount > 0) {
            // Transfer the swapped BNB to the marketing wallet
            payable(marketingWallet).transfer(bnbAmount);
            emit SwapTokensForBNB(initialBalance, path);
            emit MarketingFeesSwappedToBNB(initialBalance, bnbAmount, marketingWallet);
        }
    }



    /**
        @dev Returns true if account is excluded from fee, otherwise false.
    */
    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
    }

    /**
        @dev Excludes account from fee. Can only be called by the owner.
        @param account Address to be excluded from fee.
    */
    function excludeFromFee(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(_isExcludedFromFee[account] != true, "Account already excluded in fee");
        _isExcludedFromFee[account] = true;
        emit SetExcludeAddress(account,true);
    }

    /**
        @dev Includes account in fee. Can only be called by the owner.
        @param account Address to be included in fee.
    */
    function includeInFee(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(_isExcludedFromFee[account] != false, "Account already included in fee");
        _isExcludedFromFee[account] = false;
        emit SetExcludeAddress(account, false);
    }

    /**
        @dev Sets the marketing wallet address. Can only be called by the owner.
        @param _marketingWallet Address of the marketing wallet.
    */
    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "Invalid address");
        require(_marketingWallet != marketingWallet, "Already Set to Same Value");
        marketingWallet = _marketingWallet;
        _isExcludedFromFee[marketingWallet] = true;
        emit NewMarketingAddress(marketingWallet);
    }

    /**
        @dev Sets the address of the Pancakeswap V2 pair. Can only be called by the owner.
        @param _pancakeswapswapV2Pair Address of the Pancakeswap V2 pair.
    */
    function setPancakeswapswapV2Pair(address _pancakeswapswapV2Pair) external onlyOwner {
        require(_pancakeswapswapV2Pair != address(0), "Invalid address");
        require(_pancakeswapswapV2Pair != pancakeswapswapV2Pair, "Already Set to Same Value");
        pancakeswapswapV2Pair = _pancakeswapswapV2Pair;
        emit NewPancakePairAddress(pancakeswapswapV2Pair);
    }

    // Recommended : For stuck BNB (as a result of slight miscalculations/rounding errors) 
    function SweepStuck() external nonReentrant onlyOwner {
        require(address(this).balance>0,"No BNB to transfer");
        payable(owner()).transfer(address(this).balance);
        emit BnbRemoved(owner(),address(this).balance);
    }

    // Transfer stuck tokens of other types
    function transferForeignToken(address _token, address _to) external onlyOwner nonReentrant returns(bool _sent){
        require(_token != address(0), "Invalid address");
        require(_to != address(0), "Invalid address");
        require(_token != address(this), "Can't let you take all native token");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        require(_contractBalance>0,"ERC20: There is no balance of token inside contract");
        _sent = IERC20(_token).transfer(_to, _contractBalance);
        emit TokenRemoved(_token,_to,_contractBalance);
    }

    // To receive BNB from pancakeswapV2Router when swapping
    receive() external payable {}

    /**
        @dev Allows the contract owner to manually swap the token's marketing fees to BNB using the swapMarketingFeesToBNB() function.
        This function is only callable by the contract owner to ensure proper use and prevent unauthorized swapping.
    */
    function manualSwap(uint256 _amount) external onlyOwner{
        uint256 _contractBalance = balanceOf(address(this));
        require(_contractBalance>=_amount,"ERC20: There is low balance of token inside contract");
        swapMarketingFeesToBNB(_amount);
    }

}