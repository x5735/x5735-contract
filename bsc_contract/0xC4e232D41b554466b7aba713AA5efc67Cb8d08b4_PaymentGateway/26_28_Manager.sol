// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Context} from "../../oz/utils/Context.sol";

import {ProxyChecker} from "../../internal/ProxyChecker.sol";

import {IManager, IAuthority} from "./interfaces/IManager.sol";
import {IPausable} from "../../oz/security/Pausable.sol";
import {IAccessControl} from "../../oz/access/IAccessControl.sol";
import {IBlacklistable} from "../../internal/interfaces/IBlacklistable.sol";

import {Roles} from "../../libraries/Roles.sol";
import {ErrorHandler} from "../../libraries/ErrorHandler.sol";

import {ERC165Checker} from "../../oz/utils/introspection/ERC165Checker.sol";

abstract contract Manager is Context, IManager, ProxyChecker {
    using ErrorHandler for bool;
    using ERC165Checker for address;

    bytes32 private __authority;
    bytes32 private __requestedRole;

    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    modifier onlyWhitelisted() {
        _checkBlacklist(_msgSender());
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    constructor(IAuthority authority_, bytes32 role_) payable {
        __checkAuthority(address(authority_));

        assembly {
            sstore(__requestedRole.slot, role_)
        }
        address sender = _msgSender();
        emit RequestRoleCached(sender, role_);

        (bool ok, bytes memory revertData) = address(authority_).call(
            abi.encodeCall(IAuthority.requestAccess, (role_))
        );

        ok.handleRevertIfNotSuccess(revertData);

        __updateAuthority(authority_);
        emit AuthorityUpdated(sender, IAuthority(address(0)), authority_);
    }

    /// @inheritdoc IManager
    function updateAuthority(
        IAuthority authority_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        __checkAuthority(address(authority_));

        IAuthority old = authority();
        if (old == authority_) revert Manager__AlreadySet();
        (bool ok, bytes memory revertData) = address(authority_).call(
            abi.encodeCall(IAuthority.requestAccess, (__requestedRole))
        );

        ok.handleRevertIfNotSuccess(revertData);

        __updateAuthority(authority_);

        emit AuthorityUpdated(_msgSender(), old, authority_);
    }

    /// @inheritdoc IManager
    function authority() public view returns (IAuthority) {
        return IAuthority(_authority());
    }

    /**
     * @notice Returns the address of the authority contract, for internal use.
     * @dev This function is for internal use only and should not be called by external contracts.
     * @return authority_ is the address of the authority contract.
     */
    function _authority() internal view returns (address authority_) {
        /// @solidity memory-safe-assembly
        assembly {
            authority_ := sload(__authority.slot)
        }
    }

    /**
     * @notice Checks if the given account is blacklisted by the authority contract.
     * @param account_ The address to check for blacklisting.
     * @dev This function should be called before allowing the given account to perform certain actions.
     * @custom:throws Manager__Blacklisted if the given account is blacklisted.
     */
    function _checkBlacklist(address account_) internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IBlacklistable.isBlacklisted, (account_))
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (abi.decode(returnOrRevertData, (bool)))
            revert Manager__Blacklisted();
    }

    function _checkBlacklistMulti(address[] memory accounts_) internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IBlacklistable.areBlacklisted, (accounts_))
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (abi.decode(returnOrRevertData, (bool)))
            revert Manager__Blacklisted();
    }

    /**
     * @notice Checks if the given account has the given role.
     * @param role_ The role to check for.
     * @param account_ The address to check for the role.
     * @dev This function should be called before allowing the given account to perform certain actions.
     * @custom:throws Manager__Unauthorized if the given account does not have the given role.
     */
    function _checkRole(bytes32 role_, address account_) internal view {
        if (!_hasRole(role_, account_)) revert Manager__Unauthorized();
    }

    function __updateAuthority(IAuthority authority_) internal {
        /// @solidity memory-safe-assembly
        assembly {
            sstore(__authority.slot, authority_)
        }
    }

    function _requirePaused() internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IPausable.paused, ())
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (!abi.decode(returnOrRevertData, (bool)))
            revert Manager__NotPaused();
    }

    function _requireNotPaused() internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IPausable.paused, ())
        );
        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (abi.decode(returnOrRevertData, (bool))) revert Manager__Paused();
    }

    function _hasRole(
        bytes32 role_,
        address account_
    ) internal view returns (bool) {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IAccessControl.hasRole, (role_, account_))
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        return abi.decode(returnOrRevertData, (bool));
    }

    function __checkAuthority(address authority_) private view {
        if (
            authority_ == address(0) ||
            !_isProxy(authority_) ||
            !authority_.supportsInterface(type(IAuthority).interfaceId)
        ) revert Manager__InvalidArgument();
    }
}