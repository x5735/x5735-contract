//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ContextUpgradeable
} from "../../oz-upgradeable/utils/ContextUpgradeable.sol";
import {
    UUPSUpgradeable
} from "../../oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {
    ProxyCheckerUpgradeable
} from "../../internal-upgradeable/ProxyCheckerUpgradeable.sol";
import {IManager, IAuthority} from "./interfaces/IManager.sol";

import {
    IPausableUpgradeable
} from "../../oz-upgradeable/security/PausableUpgradeable.sol";
import {
    IAccessControlUpgradeable
} from "../../oz-upgradeable/access/IAccessControlUpgradeable.sol";
import {
    IBlacklistableUpgradeable
} from "../../internal-upgradeable/interfaces/IBlacklistableUpgradeable.sol";

import {Roles} from "../../libraries/Roles.sol";
import {ErrorHandler} from "../../libraries/ErrorHandler.sol";
import {
    ERC165CheckerUpgradeable
} from "../../oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

abstract contract ManagerUpgradeable is
    IManager,
    UUPSUpgradeable,
    ContextUpgradeable,
    ProxyCheckerUpgradeable
{
    using ErrorHandler for bool;
    using ERC165CheckerUpgradeable for address;

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

    function __Manager_init(
        IAuthority authority_,
        bytes32 role_
    ) internal onlyInitializing {
        __Manager_init_unchained(authority_, role_);
    }

    function __Manager_init_unchained(
        IAuthority authority_,
        bytes32 role_
    ) internal onlyInitializing {
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
            abi.encodeCall(IBlacklistableUpgradeable.isBlacklisted, (account_))
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (abi.decode(returnOrRevertData, (bool)))
            revert Manager__Blacklisted();
    }

    function _checkBlacklistMulti(address[] memory accounts_) internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(
                IBlacklistableUpgradeable.areBlacklisted,
                (accounts_)
            )
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
            abi.encodeCall(IPausableUpgradeable.paused, ())
        );

        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (!abi.decode(returnOrRevertData, (bool)))
            revert Manager__NotPaused();
    }

    function _requireNotPaused() internal view {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(IPausableUpgradeable.paused, ())
        );
        ok.handleRevertIfNotSuccess(returnOrRevertData);

        if (abi.decode(returnOrRevertData, (bool))) revert Manager__Paused();
    }

    function _hasRole(
        bytes32 role_,
        address account_
    ) internal view returns (bool) {
        (bool ok, bytes memory returnOrRevertData) = _authority().staticcall(
            abi.encodeCall(
                IAccessControlUpgradeable.hasRole,
                (role_, account_)
            )
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

    function _authorizeUpgrade(
        address implement_
    ) internal override onlyRole(Roles.UPGRADER_ROLE) {}

    uint256[48] private __gap;
}