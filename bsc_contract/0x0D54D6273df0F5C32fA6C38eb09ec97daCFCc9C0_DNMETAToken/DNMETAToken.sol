/**
 *Submitted for verification at BscScan.com on 2023-03-28
*/

// File: @openzeppelin\contracts\token\ERC20\IERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: @openzeppelin\contracts\token\ERC20\extensions\IERC20Metadata.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

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

// File: @openzeppelin\contracts\utils\Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin\contracts\token\ERC20\ERC20.sol

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
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
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
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
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
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
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

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
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// File: @openzeppelin\contracts\token\ERC20\extensions\ERC20Burnable.sol

// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.0;


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

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}

// File: @openzeppelin\contracts\access\Ownable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

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
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
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

// File: @openzeppelin\contracts\utils\math\SafeMath.sol

// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: contracts\DissertationNetworkMetaToken.sol

pragma solidity ^0.8.13;
/// @title Contract for Dissertation Network Meta Token (DNMETA) token.
/// @dev The contract is ERC20 compatitble
contract DNMETAToken is ERC20, ERC20Burnable, Ownable {
  struct DailySendCapInfo {
    uint256 timestamp;
    uint256 beginningBalance;
    uint256 totalSend;
  }

  mapping(address => uint256) private _balances;
  uint256 private _totalSupply;

  address[] private _accountList;
  mapping(address => bool) private _existingAccounts;

  address private _buybackAddress;
  address private _rdAddress;
  address private _marketingAddress;
  address private _burnAddress;

  mapping(address => bool) private _reflectionExceptionAddresses;

  /// anti-whale total supply cap configuration
  bool private _isTotalSupplyCapEnabled = true;
  /// anti-whale daily send cap configuration
  bool private _isDailySendCapEnabled = true;

  uint8 private _maxTotalSupplyPercentage = 5;
  uint8 private _maxDailySendPercentage = 75;

  mapping(address => DailySendCapInfo) _accountDailySendCapData;

  uint8 private constant REFLECTION_RATE = 2;
  uint8 private constant BUYBACK_RATE = 2;
  uint8 private constant RD_RATE = 2;
  uint8 private constant MARKETNG_RATE = 2;
  uint8 private constant BURN_RATE = 2;

  uint256 private constant BALANCE_SCALE = 10**9;

  uint32 private constant DAILY_SEND_CAP_PERIOD = 86400; ///seconds

  bool private _taxEnabled = true;

  address private _lastBurnAddress;

  constructor(
    address buybackAddress_,
    address researchAddress_,
    address marketingAddress_,
    address burnAddress_
  ) ERC20("DissertationNetworkMeta", "DNMETA") {
    /// 1,000,000,000 total supply of DNMETA
    _mint(msg.sender, 10**(9 + decimals()));

    _buybackAddress = buybackAddress_;
    _rdAddress = researchAddress_;
    _marketingAddress = marketingAddress_;
    _burnAddress = burnAddress_;

    _reflectionExceptionAddresses[_buybackAddress] = true;
    _reflectionExceptionAddresses[_rdAddress] = true;
    _reflectionExceptionAddresses[_marketingAddress] = true;
    _reflectionExceptionAddresses[_burnAddress] = true;
  }

  /// @inheritdoc	ERC20
  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }

  /// @inheritdoc	ERC20
  function balanceOf(address account)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _getRealBalanceAmount(_balances[account]);
  }

  function getRawBalance(address account) public view returns (uint256) {
    return _balances[account];
  }

  function setTotalSupplyCapConfiguration(bool isEnabled) public onlyOwner {
    _isTotalSupplyCapEnabled = isEnabled;
  }

  function setDailySendCapConfiguration(bool isEnabled) public onlyOwner {
    _isDailySendCapEnabled = isEnabled;
  }

  function setMaxTotalSupplyPercentage(uint8 percentage) public onlyOwner {
    _maxTotalSupplyPercentage = percentage;
  }

  function setMaxDailySendPercentage(uint8 percentage) public onlyOwner {
    _maxDailySendPercentage = percentage;
  }

  function getTotalSupplyCapConfiguration()
    public
    view
    onlyOwner
    returns (bool)
  {
    return _isTotalSupplyCapEnabled;
  }

  function getDailySendCapConfiguration() public view onlyOwner returns (bool) {
    return _isDailySendCapEnabled;
  }

  function getMaxTotalSupplyPercentage() public view onlyOwner returns (uint8) {
    return _maxTotalSupplyPercentage;
  }

  function getMaxDailySendPercentage() public view onlyOwner returns (uint8) {
    return _maxDailySendPercentage;
  }

  function setTaxConfiguration(bool isEnabled) public onlyOwner {
    _taxEnabled = isEnabled;
  }

  function getTaxEnabled() public view onlyOwner returns (bool) {
    return _taxEnabled;
  }

  /// @dev Burn by transfering tokens from an account into burn tax wallet,
  /// and reduce total supply
  function burnToBurnWallet(address account, uint256 amount) public onlyOwner {
    require(account != address(0), "burn from the zero address");

    address toAccount = _burnAddress;

    require(account != toAccount, "cannot burn tokens from burn waller");

    _beforeTokenTransfer(account, toAccount, amount);
    uint256 scaledAmount = _scaleAmount(amount);
    uint256 accountBalance = _balances[account];
    require(
      accountBalance >= scaledAmount,
      "ERC20: burn amount exceeds balance"
    );
    unchecked {
      _balances[account] = accountBalance - scaledAmount;
    }
    _balances[toAccount] += scaledAmount;
    _totalSupply -= amount;

    _lastBurnAddress = account;

    emit Transfer(account, toAccount, amount);

    _afterTokenTransfer(account, toAccount, amount);
  }

  function getLastBurnAddress() public view onlyOwner returns (address) {
    return _lastBurnAddress;
  }

  /// @dev Override _transfer to implement logic for calculating tax fees,
  /// distributing reflection, buyback, burning, transfering fees for
  /// research & development and marketing
  /// @inheritdoc	ERC20
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");

    uint256 scaledAmount = _scaleAmount(amount);
    uint256 reflectionAmount = 0;
    uint256 buybackAmount = 0;
    uint256 rdAmount = 0;
    uint256 marketingAmount = 0;
    uint256 burnAmount = 0;

    if (_taxEnabled) {
      reflectionAmount = _calReflectionAmount(scaledAmount);
      buybackAmount = _calBuybackAmount(scaledAmount);
      rdAmount = _calRDAmount(scaledAmount);
      marketingAmount = _calMarketingAmount(scaledAmount);
      burnAmount = _calBurnAmount(scaledAmount);
    }

    uint256 receivedAmount = scaledAmount -
      (reflectionAmount +
        buybackAmount +
        rdAmount +
        marketingAmount +
        burnAmount);

    _checkAllowToTransfer(from, to, scaledAmount, receivedAmount);

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = _balances[from];
    require(
      fromBalance >= scaledAmount,
      "ERC20: transfer amount exceeds balance"
    );
    unchecked {
      _balances[from] = fromBalance - scaledAmount;
    }
    _balances[to] += receivedAmount;

    if (_taxEnabled) {
      _distributeReflection(reflectionAmount);
      _buybackTax(buybackAmount);
      _rdTax(rdAmount);
      _marketingTax(marketingAmount);
      _burnTax(burnAmount);
    }

    emit Transfer(from, to, amount);

    _afterTokenTransfer(from, to, amount);
  }

  function _mint(address account, uint256 amount) internal override {
    require(account != address(0), "ERC20: mint to the zero address");

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply += amount;
    _balances[account] += _scaleAmount(amount);
    emit Transfer(address(0), account, amount);

    _afterTokenTransfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal override {
    require(account != address(0), "ERC20: burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 scaledAmount = _scaleAmount(amount);

    uint256 accountBalance = _balances[account];
    require(
      accountBalance >= scaledAmount,
      "ERC20: burn amount exceeds balance"
    );
    unchecked {
      _balances[account] = accountBalance - scaledAmount;
    }
    _totalSupply -= amount;

    emit Transfer(account, address(0), amount);

    _afterTokenTransfer(account, address(0), amount);
  }

  /// @dev Check if transaction is allowed,
  /// throw error if it's not.
  function _checkAllowToTransfer(
    address from,
    address to,
    uint256 sentAmount,
    uint256 receivedAmount
  ) internal {
    _verifyTotalSupplyCap(to, receivedAmount);
    _verifyDailySendCap(from, sentAmount);
  }

  /// @dev Anti-whale trap - verify if account balance exceeds total supply cap after transfering
  /// throw error if it's the case
  function _verifyTotalSupplyCap(address to, uint256 amount) internal view {
    if (_isTotalSupplyCapEnabled && to != owner()) {
      uint256 balance = _balances[to];
      uint256 maxBalance = _getMaxAccountBalanceWithTotalSupplyConfiguration();
      require(
        balance + amount <= maxBalance,
        "Balance exceeds total supply cap"
      );
    }
  }

  /// @dev Anti-whale trap - Verify if account total send amount exceeds max daily send setting
  /// throw error if it's the case
  function _verifyDailySendCap(address from, uint256 amount) internal {
    if (_isDailySendCapEnabled && from != owner()) {
      DailySendCapInfo storage info = _accountDailySendCapData[from];
      if (
        info.timestamp == 0 ||
        block.timestamp - info.timestamp >= DAILY_SEND_CAP_PERIOD
      ) {
        info.timestamp = block.timestamp;
        info.beginningBalance = _balances[from];
        info.totalSend = 0;
      }

      uint256 maxAmount = SafeMath.div(
        SafeMath.mul(info.beginningBalance, _maxDailySendPercentage),
        100
      );
      require(
        info.totalSend + amount <= maxAmount,
        "Total sending exceeds daily send cap"
      );
      info.totalSend += amount;
    }
  }

  function _beforeTokenTransfer(
    address, // from
    address to,
    uint256 // amount
  ) internal override {
    /// build list of account address that hold token
    /// this will help in case we want to iterate throught all holders,
    /// such as distributing reflection
    if (to != address(0) && !_existingAccounts[to]) {
      _existingAccounts[to] = true;
      _accountList.push(to);
    }
  }

  /// @dev Distribute reflection fees to all holder addresses
  function _distributeReflection(uint256 reflectionAmount) internal {
    for (uint256 i = 0; i < _accountList.length; i++) {
      address acc = _accountList[i];
      if (!_reflectionExceptionAddresses[acc] && _balances[acc] > 0) {
        uint256 amount = SafeMath.div(
          SafeMath.mul(_balances[acc], reflectionAmount),
          _scaleAmount(_totalSupply)
        );
        if (amount > 0) {
          if (acc == owner()) {
            /// don't check total supply cap for owner address
            _balances[acc] += amount;
          } else {
            if (_isTotalSupplyCapEnabled) {
              // only check for max account balance if total supply cap limit is enabled
              uint256 maxBalance = _getMaxAccountBalanceWithTotalSupplyConfiguration();
              if (_balances[acc] + amount > maxBalance) {
                /// in case distributed reflection fee makes account balance
                /// be larger than max total supply cap, then transfer the fee to buyback addr
                _balances[_buybackAddress] += amount;
              } else {
                _balances[acc] += amount;
              }
            } else {
              _balances[acc] += amount;
            }
          }
        }
      }
    }
  }

  function _buybackTax(uint256 buybackAmount) internal {
    _balances[_buybackAddress] += buybackAmount;
  }

  function _rdTax(uint256 rdAmount) internal {
    _balances[_rdAddress] += rdAmount;
  }

  function _marketingTax(uint256 marketingAmount) internal {
    _balances[_marketingAddress] += marketingAmount;
  }

  function _burnTax(uint256 burnAmount) internal {
    _balances[_burnAddress] += burnAmount;
    uint256 rBurnAmount = _getRealBalanceAmount(burnAmount);
    if (_totalSupply >= rBurnAmount) {
      _totalSupply -= rBurnAmount;
    }
  }

  function _calReflectionAmount(uint256 amount)
    internal
    pure
    returns (uint256)
  {
    return SafeMath.div(SafeMath.mul(amount, REFLECTION_RATE), 100);
  }

  function _calBuybackAmount(uint256 amount) internal pure returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, BUYBACK_RATE), 100);
  }

  function _calRDAmount(uint256 amount) internal pure returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, RD_RATE), 100);
  }

  function _calMarketingAmount(uint256 amount) internal pure returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, MARKETNG_RATE), 100);
  }

  function _calBurnAmount(uint256 amount) internal pure returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, BURN_RATE), 100);
  }

  function _scaleAmount(uint256 amount) internal pure returns (uint256) {
    return amount * BALANCE_SCALE;
  }

  function _getRealBalanceAmount(uint256 amount)
    internal
    pure
    returns (uint256)
  {
    /// round up the result number
    return SafeMath.div(amount + BALANCE_SCALE / 2, BALANCE_SCALE);
  }

  function _getMaxAccountBalanceWithTotalSupplyConfiguration()
    internal
    view
    returns (uint256)
  {
    return
      SafeMath.div(
        SafeMath.mul(_scaleAmount(_totalSupply), _maxTotalSupplyPercentage),
        100
      );
  }
}