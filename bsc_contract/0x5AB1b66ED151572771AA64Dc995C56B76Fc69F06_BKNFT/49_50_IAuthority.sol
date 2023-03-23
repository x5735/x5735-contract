// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAuthority {
    error Authority__InvalidRole();
    error Authority__LengthMismatch();

    event VaultMultiUpdated(
        address indexed operator,
        address indexed vault,
        bool[] success
    );

    event ProxyAccessGranted(address indexed operator, address indexed proxy);

    /**
     * @dev Sets the admin of the specified role to the specified admin role.
     * @param role bytes32 representing the role to set the admin of
     * @param adminRole bytes32 representing the role to set as the admin of the role
     */
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    /**
     * @dev Allows a user to request access to the contract as a proxy.
     * Only callable by accounts with the OPERATOR_ROLE and only if the sender is a proxy of the caller.
     * Grants the PROXY_ROLE and the specified role to the sender.
     * @param role bytes32 representing the role to grant to the sender in addition to the PROXY_ROLE
     */
    function requestAccess(bytes32 role) external;
}