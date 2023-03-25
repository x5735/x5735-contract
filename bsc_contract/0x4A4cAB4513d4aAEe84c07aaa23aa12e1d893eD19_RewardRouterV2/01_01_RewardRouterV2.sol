// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


// File contracts/libraries/token/IERC20.sol


pragma solidity 0.6.12;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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


// File contracts/libraries/utils/Address.sol


pragma solidity ^0.6.2;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File contracts/libraries/token/SafeERC20.sol


pragma solidity 0.6.12;



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
    using SafeMath for uint256;
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
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File contracts/libraries/utils/ReentrancyGuard.sol


pragma solidity 0.6.12;

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
contract ReentrancyGuard {
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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}



pragma solidity 0.6.12;

interface IMintable {
    function isMinter(address _account) external returns (bool);
    function setMinter(address _minter, bool _isActive) external;
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}


pragma solidity 0.6.12;

interface IDlpManager {
    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minDlp) external returns (uint256);
    function addLiquidityForAccount(address _fundingAccount, address _account, address _token, uint256 _amount, uint256 _minUsdg, uint256 _minDlp) external returns (uint256);
    function removeLiquidity(address _tokenOut, uint256 _DlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function removeLiquidityForAccount(address _account, address _tokenOut, uint256 _DlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}


pragma solidity 0.6.12;

contract Governable {
    address public gov;

    constructor() public {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}

pragma solidity 0.6.12;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}


pragma solidity 0.6.12;

interface IVester {
    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function transferredAverageStakedAmounts(address _account) external view returns (uint256);
    function transferredCumulativeRewards(address _account) external view returns (uint256);
    function cumulativeRewardDeductions(address _account) external view returns (uint256);
    function bonusRewards(address _account) external view returns (uint256);

    function transferStakeValues(address _sender, address _receiver) external;
    function setTransferredAverageStakedAmounts(address _account, uint256 _amount) external;
    function setTransferredCumulativeRewards(address _account, uint256 _amount) external;
    function setCumulativeRewardDeductions(address _account, uint256 _amount) external;
    function setBonusRewards(address _account, uint256 _amount) external;

    function getMaxVestableAmount(address _account) external view returns (uint256);
    function getCombinedAverageStakedAmount(address _account) external view returns (uint256);
}

pragma solidity 0.6.12;

interface IRewardTracker {
    function depositBalances(address _account, address _depositToken) external view returns (uint256);
    function stakedAmounts(address _account) external view returns (uint256);
    function updateRewards() external;
    function stake(address _depositToken, uint256 _amount) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external;
    function unstake(address _depositToken, uint256 _amount) external;
    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external;
    function tokensPerInterval() external view returns (uint256);
    function claim(address _receiver) external returns (uint256);
    function claimForAccount(address _account, address _receiver) external returns (uint256);
    function claimable(address _account) external view returns (uint256);
    function averageStakedAmounts(address _account) external view returns (uint256);
    function cumulativeRewards(address _account) external view returns (uint256);
}


pragma solidity 0.6.12;

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public Dxp;
    address public esDxp;
    address public bnDxp;

    address public Dlp; // Dxp Liquidity Provider token

    address public stakedDxpTracker;
    address public bonusDxpTracker;
    address public feeDxpTracker;

    address public stakedDlpTracker;
    address public feeDlpTracker;

    address public DlpManager;

    address public DxpVester;
    address public DlpVester;

    mapping (address => address) public pendingReceivers;

    event StakeDxp(address account, address token, uint256 amount);
    event UnstakeDxp(address account, address token, uint256 amount);

    event StakeDlp(address account, uint256 amount);
    event UnstakeDlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _Dxp,
        address _esDxp,
        address _bnDxp,
        address _Dlp,
        address _stakedDxpTracker,
        address _bonusDxpTracker,
        address _feeDxpTracker,
        address _feeDlpTracker,
        address _stakedDlpTracker,
        address _DlpManager,
        address _DxpVester,
        address _DlpVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        Dxp = _Dxp;
        esDxp = _esDxp;
        bnDxp = _bnDxp;

        Dlp = _Dlp;

        stakedDxpTracker = _stakedDxpTracker;
        bonusDxpTracker = _bonusDxpTracker;
        feeDxpTracker = _feeDxpTracker;

        feeDlpTracker = _feeDlpTracker;
        stakedDlpTracker = _stakedDlpTracker;

        DlpManager = _DlpManager;

        DxpVester = _DxpVester;
        DlpVester = _DlpVester;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeDxpForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _Dxp = Dxp;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeDxp(msg.sender, _accounts[i], _Dxp, _amounts[i]);
        }
    }

    function stakeDxpForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeDxp(msg.sender, _account, Dxp, _amount);
    }

    function stakeDxp(uint256 _amount) external nonReentrant {
        _stakeDxp(msg.sender, msg.sender, Dxp, _amount);
    }

    function stakeEsDxp(uint256 _amount) external nonReentrant {
        _stakeDxp(msg.sender, msg.sender, esDxp, _amount);
    }

    function unstakeDxp(uint256 _amount) external nonReentrant {
        _unstakeDxp(msg.sender, Dxp, _amount, true);
    }

    function unstakeEsDxp(uint256 _amount) external nonReentrant {
        _unstakeDxp(msg.sender, esDxp, _amount, true);
    }

    function mintAndStakeDlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minDlp) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 DlpAmount = IDlpManager(DlpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdg, _minDlp);
        IRewardTracker(feeDlpTracker).stakeForAccount(account, account, Dlp, DlpAmount);
        IRewardTracker(stakedDlpTracker).stakeForAccount(account, account, feeDlpTracker, DlpAmount);

        emit StakeDlp(account, DlpAmount);

        return DlpAmount;
    }

    function mintAndStakeDlpETH(uint256 _minUsdg, uint256 _minDlp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(DlpManager, msg.value);

        address account = msg.sender;
        uint256 DlpAmount = IDlpManager(DlpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdg, _minDlp);

        IRewardTracker(feeDlpTracker).stakeForAccount(account, account, Dlp, DlpAmount);
        IRewardTracker(stakedDlpTracker).stakeForAccount(account, account, feeDlpTracker, DlpAmount);

        emit StakeDlp(account, DlpAmount);

        return DlpAmount;
    }

    function unstakeAndRedeemDlp(address _tokenOut, uint256 _DlpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
        require(_DlpAmount > 0, "RewardRouter: invalid _DlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedDlpTracker).unstakeForAccount(account, feeDlpTracker, _DlpAmount, account);
        IRewardTracker(feeDlpTracker).unstakeForAccount(account, Dlp, _DlpAmount, account);
        uint256 amountOut = IDlpManager(DlpManager).removeLiquidityForAccount(account, _tokenOut, _DlpAmount, _minOut, _receiver);

        emit UnstakeDlp(account, _DlpAmount);

        return amountOut;
    }

    function unstakeAndRedeemDlpETH(uint256 _DlpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
        require(_DlpAmount > 0, "RewardRouter: invalid _DlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedDlpTracker).unstakeForAccount(account, feeDlpTracker, _DlpAmount, account);
        IRewardTracker(feeDlpTracker).unstakeForAccount(account, Dlp, _DlpAmount, account);
        uint256 amountOut = IDlpManager(DlpManager).removeLiquidityForAccount(account, weth, _DlpAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeDlp(account, _DlpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeDxpTracker).claimForAccount(account, account);
        IRewardTracker(feeDlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedDxpTracker).claimForAccount(account, account);
        IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
    }

    function claimEsDxp() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedDxpTracker).claimForAccount(account, account);
        IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeDxpTracker).claimForAccount(account, account);
        IRewardTracker(feeDlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimDxp,
        bool _shouldStakeDxp,
        bool _shouldClaimEsDxp,
        bool _shouldStakeEsDxp,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 DxpAmount = 0;
        if (_shouldClaimDxp) {
            uint256 DxpAmount0 = IVester(DxpVester).claimForAccount(account, account);
            uint256 DxpAmount1 = IVester(DlpVester).claimForAccount(account, account);
            DxpAmount = DxpAmount0.add(DxpAmount1);
        }

        if (_shouldStakeDxp && DxpAmount > 0) {
            _stakeDxp(account, account, Dxp, DxpAmount);
        }

        uint256 esDxpAmount = 0;
        if (_shouldClaimEsDxp) {
            uint256 esDxpAmount0 = IRewardTracker(stakedDxpTracker).claimForAccount(account, account);
            uint256 esDxpAmount1 = IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
            esDxpAmount = esDxpAmount0.add(esDxpAmount1);
        }

        if (_shouldStakeEsDxp && esDxpAmount > 0) {
            _stakeDxp(account, account, esDxp, esDxpAmount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnDxpAmount = IRewardTracker(bonusDxpTracker).claimForAccount(account, account);
            if (bnDxpAmount > 0) {
                IRewardTracker(feeDxpTracker).stakeForAccount(account, account, bnDxp, bnDxpAmount);
            }
        }

        if (_shouldClaimWeth) {
            if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeDxpTracker).claimForAccount(account, address(this));
                uint256 weth1 = IRewardTracker(feeDlpTracker).claimForAccount(account, address(this));

                uint256 wethAmount = weth0.add(weth1);
                IWETH(weth).withdraw(wethAmount);

                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeDxpTracker).claimForAccount(account, account);
                IRewardTracker(feeDlpTracker).claimForAccount(account, account);
            }
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function signalTransfer(address _receiver) external nonReentrant {
        require(IERC20(DxpVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(DlpVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(IERC20(DxpVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(DlpVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");

        address receiver = msg.sender;
        require(pendingReceivers[_sender] == receiver, "RewardRouter: transfer not signalled");
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedDxp = IRewardTracker(stakedDxpTracker).depositBalances(_sender, Dxp);
        if (stakedDxp > 0) {
            _unstakeDxp(_sender, Dxp, stakedDxp, false);
            _stakeDxp(_sender, receiver, Dxp, stakedDxp);
        }

        uint256 stakedEsDxp = IRewardTracker(stakedDxpTracker).depositBalances(_sender, esDxp);
        if (stakedEsDxp > 0) {
            _unstakeDxp(_sender, esDxp, stakedEsDxp, false);
            _stakeDxp(_sender, receiver, esDxp, stakedEsDxp);
        }

        uint256 stakedBnDxp = IRewardTracker(feeDxpTracker).depositBalances(_sender, bnDxp);
        if (stakedBnDxp > 0) {
            IRewardTracker(feeDxpTracker).unstakeForAccount(_sender, bnDxp, stakedBnDxp, _sender);
            IRewardTracker(feeDxpTracker).stakeForAccount(_sender, receiver, bnDxp, stakedBnDxp);
        }

        uint256 esDxpBalance = IERC20(esDxp).balanceOf(_sender);
        if (esDxpBalance > 0) {
            IERC20(esDxp).transferFrom(_sender, receiver, esDxpBalance);
        }

        uint256 DlpAmount = IRewardTracker(feeDlpTracker).depositBalances(_sender, Dlp);
        if (DlpAmount > 0) {
            IRewardTracker(stakedDlpTracker).unstakeForAccount(_sender, feeDlpTracker, DlpAmount, _sender);
            IRewardTracker(feeDlpTracker).unstakeForAccount(_sender, Dlp, DlpAmount, _sender);

            IRewardTracker(feeDlpTracker).stakeForAccount(_sender, receiver, Dlp, DlpAmount);
            IRewardTracker(stakedDlpTracker).stakeForAccount(receiver, receiver, feeDlpTracker, DlpAmount);
        }

        IVester(DxpVester).transferStakeValues(_sender, receiver);
        IVester(DlpVester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(IRewardTracker(stakedDxpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedDxpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedDxpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedDxpTracker.cumulativeRewards > 0");

        require(IRewardTracker(bonusDxpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: bonusDxpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(bonusDxpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: bonusDxpTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeDxpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeDxpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeDxpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeDxpTracker.cumulativeRewards > 0");

        require(IVester(DxpVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: DxpVester.transferredAverageStakedAmounts > 0");
        require(IVester(DxpVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: DxpVester.transferredCumulativeRewards > 0");

        require(IRewardTracker(stakedDlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedDlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedDlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedDlpTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeDlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeDlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeDlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeDlpTracker.cumulativeRewards > 0");

        require(IVester(DlpVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: DxpVester.transferredAverageStakedAmounts > 0");
        require(IVester(DlpVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: DxpVester.transferredCumulativeRewards > 0");

        require(IERC20(DxpVester).balanceOf(_receiver) == 0, "RewardRouter: DxpVester.balance > 0");
        require(IERC20(DlpVester).balanceOf(_receiver) == 0, "RewardRouter: DlpVester.balance > 0");
    }

    function _compound(address _account) private {
        _compoundDxp(_account);
        _compoundDlp(_account);
    }

    function _compoundDxp(address _account) private {
        uint256 esDxpAmount = IRewardTracker(stakedDxpTracker).claimForAccount(_account, _account);
        if (esDxpAmount > 0) {
            _stakeDxp(_account, _account, esDxp, esDxpAmount);
        }

        uint256 bnDxpAmount = IRewardTracker(bonusDxpTracker).claimForAccount(_account, _account);
        if (bnDxpAmount > 0) {
            IRewardTracker(feeDxpTracker).stakeForAccount(_account, _account, bnDxp, bnDxpAmount);
        }
    }

    function _compoundDlp(address _account) private {
        uint256 esDxpAmount = IRewardTracker(stakedDlpTracker).claimForAccount(_account, _account);
        if (esDxpAmount > 0) {
            _stakeDxp(_account, _account, esDxp, esDxpAmount);
        }
    }

    function _stakeDxp(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedDxpTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusDxpTracker).stakeForAccount(_account, _account, stakedDxpTracker, _amount);
        IRewardTracker(feeDxpTracker).stakeForAccount(_account, _account, bonusDxpTracker, _amount);

        emit StakeDxp(_account, _token, _amount);
    }

    function _unstakeDxp(address _account, address _token, uint256 _amount, bool _shouldReduceBnDxp) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedDxpTracker).stakedAmounts(_account);

        IRewardTracker(feeDxpTracker).unstakeForAccount(_account, bonusDxpTracker, _amount, _account);
        IRewardTracker(bonusDxpTracker).unstakeForAccount(_account, stakedDxpTracker, _amount, _account);
        IRewardTracker(stakedDxpTracker).unstakeForAccount(_account, _token, _amount, _account);

        if (_shouldReduceBnDxp) {
            uint256 bnDxpAmount = IRewardTracker(bonusDxpTracker).claimForAccount(_account, _account);
            if (bnDxpAmount > 0) {
                IRewardTracker(feeDxpTracker).stakeForAccount(_account, _account, bnDxp, bnDxpAmount);
            }

            uint256 stakedBnDxp = IRewardTracker(feeDxpTracker).depositBalances(_account, bnDxp);
            if (stakedBnDxp > 0) {
                uint256 reductionAmount = stakedBnDxp.mul(_amount).div(balance);
                IRewardTracker(feeDxpTracker).unstakeForAccount(_account, bnDxp, reductionAmount, _account);
                IMintable(bnDxp).burn(_account, reductionAmount);
            }
        }

        emit UnstakeDxp(_account, _token, _amount);
    }
}