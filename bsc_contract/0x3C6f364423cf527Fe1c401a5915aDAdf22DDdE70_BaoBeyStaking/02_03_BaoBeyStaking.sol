// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ABDKMath64x64.sol";
import "./SafeMath.sol";

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
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

    function decimals() external view returns (uint8);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    bool private has_transfer = false;

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
        require(!has_transfer, "TransferOwnership already called");
        _transferOwnership(newOwner);
        has_transfer = true;
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

contract BaoBeyStaking is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 private immutable _token;

    uint256 private constant DAY = 1 days;
    uint256 private constant MONTH = 30 days;
    uint256 private constant YEAR = 365 days;
    uint8 constant decimal_token = 9;

    uint256 public total_staked = 0;
    bool public contract_deposit_paused = false;
    bool public contract_withdraw_paused = false;

    uint256 public initial_pool_value = 0;

    mapping(address => bool) private locked;

    struct IndDepositStruct {
        uint256 index;
        uint256 date;
        uint256 amount;
        uint256 amount_to_claim;
        uint256 id;
        uint256 date_claimed;
    }
    mapping(address => IndDepositStruct[]) public walletDeposits;

    struct DepositStruct {
        address wallet;
        uint256 date;
        uint256 amount;
        uint256 amount_to_claim;
        uint256 id;
    }
    DepositStruct[] public arrDeposit;

    modifier validDepositId(uint256 _depositId) {
        require(_depositId >= 0 && _depositId <= 3, "Invalid depositId");
        _;
    }

    modifier isNotLocked(address _address) {
        require(locked[_address] == false, "Locked, try again later");
        _;
    }

    modifier walletDepositExist(uint256 _index) {
        require(walletDeposits[_msgSender()].length > _index, "user deposit not exist");
        _;
    }

    modifier balanceExists(uint256 _index) {
        require(
            walletDeposits[_msgSender()][_index].date_claimed == 0 && walletDeposits[_msgSender()][_index].amount > 0,
            "Your deposit is zero"
        );
        _;
    }

    modifier isNotPausedDeposit() {
        require(contract_deposit_paused == false, "Deposit Paused");
        _;
    }

    modifier isNotPausedWithdraw() {
        require(contract_withdraw_paused == false, "Withdraw Paused");
        _;
    }

    modifier checkEnoughPool(uint256 _amount, uint256 _depositId) {
        require(checkPoolIsEnough(_amount, _depositId), "pool reward insufficient");
        _;
    }

    event Deposited(address indexed sender, uint256 indexed id, uint256 amount, uint256 index);
    event Withdrawed(
        address indexed sender,
        uint256 indexed id,
        uint256 totalWithdrawalAmount,
        uint256 index,
        uint256 timestamp
    );
    event UpdatedInitialPoolValue(uint256 amount, bool operation);
    event ContractDepositPaused(bool value);
    event ContractWithdrawPaused(bool value);

    constructor(IERC20 token) {
        _token = token;
    }

    //external
    function deposit(
        uint256 _depositId,
        uint256 _amount
    )
        external
        validDepositId(_depositId)
        isNotLocked(_msgSender())
        isNotPausedDeposit
        checkEnoughPool(_amount, _depositId)
    {
        require(_amount > 0, "Amount should be more than 0");

        _setLocked(_msgSender(), true);
        _deposit(_msgSender(), _depositId, _amount);
        _token.safeTransferFrom(_msgSender(), address(this), _amount);
        _setLocked(_msgSender(), false);
    }

    function withdrawAll(uint256 _index) external walletDepositExist(_index) balanceExists(_index) isNotPausedWithdraw {
        require(isLockupPeriodExpired(_msgSender(), _index), "Too early, Lockup period");
        _withdrawAll(_msgSender(), _index);
    }

    //public view
    function getDepositsByWalletRaw(
        address _address
    )
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory index = new uint256[](walletDeposits[_address].length);
        uint256[] memory date = new uint256[](walletDeposits[_address].length);
        uint256[] memory amount = new uint256[](walletDeposits[_address].length);
        uint256[] memory amount_to_claim = new uint256[](walletDeposits[_address].length);
        uint256[] memory id = new uint256[](walletDeposits[_address].length);
        uint256[] memory date_claimed = new uint256[](walletDeposits[_address].length);
        for (uint i = 0; i < walletDeposits[_address].length; i++) {
            index[i] = walletDeposits[_address][i].index;
            date[i] = walletDeposits[_address][i].date;
            amount[i] = walletDeposits[_address][i].amount;
            amount_to_claim[i] = walletDeposits[_address][i].amount_to_claim;
            id[i] = walletDeposits[_address][i].id;
            date_claimed[i] = walletDeposits[_address][i].date_claimed;
        }
        return (index, date, amount, amount_to_claim, id, date_claimed);
    }

    function getVigentDepositsByWalletAndId(address _address, uint256 _depositId) public view returns (uint256) {
        uint256 _amount;
        uint256 length = walletDeposits[_address].length;
        for (uint i = 0; i < length; i++) {
            if (walletDeposits[_address][i].id == _depositId) {
                if (isLockupPeriodExpired(_address, walletDeposits[_address][i].index) == false)
                    _amount += walletDeposits[_address][i].amount;
            }
        }
        return _amount;
    }

    function isLockupPeriodExpired(
        address _address,
        uint256 _index
    ) public view walletDepositExist(_index) returns (bool) {
        IndDepositStruct storage user = walletDeposits[_address][_index];
        uint256 lockPeriod;
        uint256 _depositId = user.id;

        if (_depositId == 0) {
            lockPeriod = MONTH * 3; // 3 months
        } else if (_depositId == 1) {
            lockPeriod = MONTH * 6; // 6 months
        } else if (_depositId == 2) {
            lockPeriod = MONTH * 9; // 9 months
        } else if (_depositId == 3) {
            lockPeriod = MONTH * 12; // 12 months
        }
        if (_now() > user.date.add(lockPeriod)) {
            return true;
        } else {
            return false;
        }
    }

    function checkPoolIsEnough(uint256 _amount, uint256 _depositId) public view returns (bool) {
        uint256 finalBalance = calcForm(_amount, _depositId);
        if ((finalBalance - _amount) <= initial_pool_value) {
            return true;
        } else {
            return false;
        }
    }

    //external view
    function getAllDeposit() external view returns (DepositStruct[] memory) {
        return arrDeposit;
    }

    function getDepositsByWallet(address _address) external view returns (IndDepositStruct[] memory) {
        return walletDeposits[_address];
    }

    function getBalanceActiveDepositsByWallet(address _address) external view returns (uint256) {
        uint256 balance = 0;
        for (uint i = 0; i < walletDeposits[_address].length; i++) {
            if (walletDeposits[_address][i].date_claimed == 0) {
                balance = balance.add(walletDeposits[_address][i].amount);
            }
        }
        return balance;
    }

    //public pure
    function calcForm(uint256 currentBalance, uint256 _depositId) public pure returns (uint256 finalBalance) {
        uint256 autocompound = 0;
        uint256 ratio;
        uint256 lockPeriod;

        if (_depositId == 0) {
            ratio = 50000000000000000;
            lockPeriod = MONTH * 3; // 3 months
            autocompound = 1;
        } else if (_depositId == 1) {
            ratio = 100000000000000000;
            lockPeriod = MONTH * 6; // 6 months
            autocompound = 2;
        } else if (_depositId == 2) {
            ratio = 150000000000000000;
            lockPeriod = MONTH * 9; // 9 months
            autocompound = 3;
        } else if (_depositId == 3) {
            ratio = 200000000000000000;
            lockPeriod = YEAR; // 12 months
            autocompound = 4;
        }

        finalBalance = compound(currentBalance, ratio, autocompound);
    }

    //internal
    function _setLocked(address _address, bool _locked) internal {
        locked[_address] = _locked;
    }

    function _deposit(address _sender, uint256 _depositId, uint256 _amount) internal {
        uint256 _index = walletDeposits[_msgSender()].length;

        uint256 finalBalance = calcForm(_amount, _depositId);
        uint256 timestamp = _now();

        arrDeposit.push(DepositStruct(_msgSender(), timestamp, _amount, finalBalance, _depositId));

        walletDeposits[_msgSender()].push(IndDepositStruct(_index, timestamp, _amount, finalBalance, _depositId, 0));

        unchecked {
            total_staked += _amount;
            initial_pool_value -= (finalBalance - _amount);
        }

        emit Deposited(_sender, _depositId, _amount, _index);
    }

    function _withdrawAll(address _sender, uint256 _index) internal {
        IndDepositStruct storage user = walletDeposits[_msgSender()][_index];

        _setLocked(_msgSender(), true);
        _token.safeTransfer(_sender, user.amount_to_claim);
        user.date_claimed = _now();
        _setLocked(_msgSender(), false);

        emit Withdrawed(_sender, user.id, user.amount_to_claim, _index, _now());
    }

    function compound(uint256 _principal, uint256 _ratio, uint256 daysCount) internal pure returns (uint256) {
        return
            ABDKMath64x64.mulu(
                pow(
                    ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio / daysCount, 10 ** 18)),
                    1 * daysCount
                ),
                _principal
            );
    }

    function pow(int128 _x, uint256 _n) internal pure returns (int128 r) {
        r = ABDKMath64x64.fromUInt(1);
        while (_n > 0) {
            if (_n % 2 == 1) {
                r = ABDKMath64x64.mul(r, _x);
                _n -= 1;
            } else {
                _x = ABDKMath64x64.mul(_x, _x);
                _n /= 2;
            }
        }
    }

    function _now() internal view returns (uint256) {
        return block.timestamp;
    }

    //onlyOwner
    function updateInitialPoolValue(uint256 _initialPoolValue, bool operation) external onlyOwner {
        if (operation == true) {
            initial_pool_value += _initialPoolValue * 10 ** decimal_token;
        } else {
            require(initial_pool_value <= _initialPoolValue, "value cannot be greater than the current value");
            initial_pool_value -= _initialPoolValue * 10 ** decimal_token;
        }
        emit UpdatedInitialPoolValue(_initialPoolValue, operation);
    }

    function setContractDepositPaused(bool _value) external onlyOwner {
        contract_deposit_paused = _value;

        emit ContractDepositPaused(_value);
    }

    function setContractWithdrawPaused(bool _value) external onlyOwner {
        contract_withdraw_paused = _value;

        emit ContractWithdrawPaused(_value);
    }
}