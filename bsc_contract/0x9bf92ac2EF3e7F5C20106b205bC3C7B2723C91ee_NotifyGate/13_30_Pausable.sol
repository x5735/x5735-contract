// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.17;

import {Context} from "../utils/Context.sol";

interface IPausable {
    error Pausable__Paused();
    error Pausable__NotPaused();

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address indexed account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address indexed account);

    /**
     * @dev Pauses all functions in the contract. Only callable by accounts with the PAUSER_ROLE.
     */
    function pause() external;

    /**
     * @dev Unpauses all functions in the contract. Only callable by accounts with the PAUSER_ROLE.
     */
    function unpause() external;

    function paused() external view returns (bool isPaused);
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context, IPausable {
    uint256 private __paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() payable {
        assembly {
            sstore(__paused.slot, 1)
        }
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool isPaused) {
        assembly {
            isPaused := eq(2, sload(__paused.slot))
        }
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        assembly {
            if eq(2, sload(__paused.slot)) {
                mstore(0x00, 0x059519da)
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        assembly {
            if eq(1, sload(__paused.slot)) {
                mstore(0x00, 0x59488a5a)
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        address sender = _msgSender();
        assembly {
            sstore(__paused.slot, 2)
            log2(
                0,
                0,
                /// @dev value is equal to keccak256("Paused(address)")
                0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258,
                sender
            )
        }
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        address sender = _msgSender();
        assembly {
            sstore(__paused.slot, 1)
            log2(
                0,
                0,
                /// @dev value is equal to keccak256("Unpaused(address)")
                0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa,
                sender
            )
        }
    }
}