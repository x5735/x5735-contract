// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ContextUpgradeable
} from "../oz-upgradeable/utils/ContextUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "../oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "../oz-upgradeable/proxy/utils/Initializable.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";
import {Bytes32Address} from "../libraries/Bytes32Address.sol";

error MultiDelegatecall__OnlyDelegatecall();
error MultiDelegatecall__DelegatecallNotAllowed();

/**
 * @title MultiDelegatecallUpgradeable
 * @dev Abstract contract for performing multiple delegatecalls in a single transaction.
 */
abstract contract MultiDelegatecallUpgradeable is
    Initializable,
    ContextUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ErrorHandler for bool;
    using Bytes32Address for address;

    /**
     * @dev Address of the original contract
     */
    bytes32 private __original;

    modifier onlyDelegatecalll() {
        __onlyDelegateCall(__original);
        _;
    }

    event BatchExecutionDelegated(
        address indexed operator,
        bytes[] callData,
        bytes[] results
    );

    function __MultiDelegatecall_init() internal virtual onlyInitializing {
        __ReentrancyGuard_init_unchained();
        __MultiDelegatecall_init_unchained();
    }

    function __MultiDelegatecall_init_unchained()
        internal
        virtual
        onlyInitializing
    {
        assembly {
            sstore(__original.slot, address())
        }
    }

    /**
     * @dev Executes multiple delegatecalls in a single transaction
     * @param data_ Array of calldata for delegatecalls
     * @return results Array of delegatecall results
     */
    function _multiDelegatecall(
        bytes[] calldata data_
    )
        internal
        virtual
        onlyDelegatecalll
        nonReentrant
        returns (bytes[] memory results)
    {
        uint256 length = data_.length;
        results = new bytes[](length);
        bool ok;
        bytes memory result;
        for (uint256 i; i < length; ) {
            (ok, result) = address(this).delegatecall(data_[i]);

            ok.handleRevertIfNotSuccess(result);

            results[i] = result;

            unchecked {
                ++i;
            }
        }

        emit BatchExecutionDelegated(_msgSender(), data_, results);
    }

    function __onlyDelegateCall(bytes32 originalBytes_) private view {
        if (address(this).fillLast12Bytes() == originalBytes_)
            revert MultiDelegatecall__OnlyDelegatecall();
    }

    uint256[49] private __gap;
}