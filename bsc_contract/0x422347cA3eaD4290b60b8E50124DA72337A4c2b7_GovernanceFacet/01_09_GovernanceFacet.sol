//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IGovernance.sol";
import "../libraries/LibGovernance.sol";
import "../libraries/LibRouter.sol";
import "../Governable.sol";

/// @notice Handles the management of governance members
contract GovernanceFacet is IGovernance, Governable {
    using Counters for Counters.Counter;

    /**
     * @notice sets the state for the Governance facet
     * @param data_ Abi encoded data - the list of governance members.
     * @dev This state method is never attached on the diamond
     */
    function state(bytes memory data_) external {
        (address[] memory members) = abi.decode(data_, (address[]));
        require(members.length > 0, "Governance: member list empty");
        for (uint256 i = 0; i < members.length;) {
            LibGovernance.updateMember(members[i], true);
            emit MemberUpdated(members[i], true);
            unchecked { i += 1; }
        }
    }

    /**
     *  @notice Adds/removes a member account
     *  @param account_ The account to be modified
     *  @param status_ Whether the account will be set as member or not
     *  @param signatures_ The signatures of the validators authorizing this member update
     */
    function updateMember(address account_, bool status_, bytes[] calldata signatures_)
        onlyConsensusNonce(computeMemberUpdateMessage(account_, status_), signatures_)
        external override
    {
        require(account_ != address(0));

        LibGovernance.updateMember(account_, status_);
        emit MemberUpdated(account_, status_);
    }

    /// @notice Computes the bytes32 ethereum signed message hash of the member update message
    function computeMemberUpdateMessage(address account_, bool status_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeMemberUpdateMessage",
                account_, status_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /// @return True/false depending on whether a given address is member or not
    function isMember(address member_) external view override returns (bool) {
        return LibGovernance.isMember(member_);
    }

    /// @return The count of members in the members set
    function membersCount() external view override returns (uint256) {
        return LibGovernance.membersCount();
    }

    /// @return The address of a member at a given index
    function memberAt(uint256 index_) external view override returns (address) {
        return LibGovernance.memberAt(index_);
    }

    /// @return The current administrative nonce
    function administrativeNonce() external view override returns (uint256) {
        return LibGovernance.governanceStorage().administrativeNonce.current();
    }
}