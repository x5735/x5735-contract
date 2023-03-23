// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import {IERC721Upgradeable} from "../IERC721Upgradeable.sol";

/// @title ERC721 with permit
/// @notice Extension to ERC721 that includes a permit function for signature based approvals
interface IERC721PermitUpgradeable is IERC721Upgradeable {
    error ERC721Permit__Expired();
    error ERC721Permit__SelfApproving();

    /// @notice The domain separator used in the permit signature
    /// @return The domain seperator used in encoding of permit signature
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice function to be called by anyone to approve `spender` using a Permit signature
    /// @dev Anyone can call this to approve `spender`, even a third-party
    /// @param spender the actor to approve
    /// @param tokenId the token id
    /// @param deadline the deadline for the permit to be used
    /// @param signature permit
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        bytes calldata signature
    ) external;

    function nonces(uint256 tokenId_) external view returns (uint256);
}