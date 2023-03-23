// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ContextUpgradeable
} from "../oz-upgradeable/utils/ContextUpgradeable.sol";

import {TransferableUpgradeable} from "./TransferableUpgradeable.sol";
import {ProxyCheckerUpgradeable} from "./ProxyCheckerUpgradeable.sol";

import {
    IERC20Upgradeable,
    IERC721Upgradeable,
    IFundForwarderUpgradeable,
    IERC721EnumerableUpgradeable
} from "./interfaces/IFundForwarderUpgradeable.sol";

import {ErrorHandler} from "../libraries/ErrorHandler.sol";

/**
 * @title FundForwarderUpgradeable
 * @dev Abstract contract for forwarding funds to a specified address.
 */
abstract contract FundForwarderUpgradeable is
    ContextUpgradeable,
    ProxyCheckerUpgradeable,
    TransferableUpgradeable,
    IFundForwarderUpgradeable
{
    using ErrorHandler for bool;

    /**
     * @dev Address to forward funds to
     */
    bytes32 private __vault;

    /**
     * @dev Receives funds and forwards them to the vault address
     */
    receive() external payable virtual onlyEOA {
        address _vault = vault();

        _safeNativeTransfer(_vault, msg.value, safeRecoverHeader());

        emit Forwarded(_msgSender(), msg.value);

        _afterRecover(_vault, address(0), msg.value, "");
    }

    function __FundForwarder_init(
        address vault_
    ) internal virtual onlyInitializing {
        __FundForwarder_init_unchained(vault_);
    }

    function __FundForwarder_init_unchained(
        address vault_
    ) internal virtual onlyInitializing {
        _changeVault(vault_);
    }

    function recover(RecoveryCallData[] calldata calldata_) external virtual {
        _beforeRecover("");

        address _vault = vault();
        address sender = _msgSender();
        uint256 length = calldata_.length;
        bytes[] memory results = new bytes[](length);

        bool ok;
        bytes memory result;
        for (uint256 i; i < length; ) {
            (ok, result) = calldata_[i].token.call{value: calldata_[i].value}(
                abi.encodePacked(calldata_[i].fnSelector, calldata_[i].params)
            );

            ok.handleRevertIfNotSuccess(result);

            results[i] = result;

            _afterRecover(
                _vault,
                calldata_[i].token,
                calldata_[i].value,
                calldata_[i].params
            );

            emit Recovered(
                sender,
                calldata_[i].token,
                calldata_[i].value,
                calldata_[i].params
            );

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IFundForwarderUpgradeable
    function recoverNative() external virtual {
        _beforeRecover("");
        address sender = _msgSender();
        _onlyEOA(sender);

        address _vault = vault();
        uint256 balance = address(this).balance;
        _safeNativeTransfer(_vault, balance, safeRecoverHeader());

        emit Recovered(sender, address(0), balance, "");

        _afterRecover(_vault, address(0), balance, "");
    }

    function vault() public view virtual returns (address vault_) {
        assembly {
            vault_ := sload(__vault.slot)
        }

        _checkValidAddress(vault_);
    }

    /**
     * @dev Changes the vault address
     * @param vault_ New vault address
     */
    function _changeVault(address vault_) internal virtual {
        _checkValidAddress(vault_);

        assembly {
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("VaultUpdated(address,address,address)")
                0x2afec66505e0ceed692012e3833f6609d4933ded34732135bc05f28423744065,
                caller(),
                sload(__vault.slot),
                vault_
            )

            sstore(__vault.slot, vault_)
        }
    }

    function safeRecoverHeader() public pure virtual returns (bytes memory);

    function safeTransferHeader() public pure virtual returns (bytes memory);

    function _beforeRecover(bytes memory data_) internal virtual;

    function _afterRecover(
        address vault_,
        address token_,
        uint256 value_,
        bytes memory params_
    ) internal virtual;

    /**
     *@dev Asserts that the given address is not the zero address
     *@param addr_ The address to check
     *@custom:throws FundForwarder__InvalidArgument if the address is the zero address
     */
    function _checkValidAddress(address addr_) internal view virtual {
        if (addr_ == address(0) || addr_ == address(this))
            revert FundForwarder__InvalidArgument();
    }

    uint256[49] private __gap;
}