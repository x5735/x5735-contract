// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketplaceV1.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract MarketplaceV2 is MarketplaceV1, AccessControlUpgradeable {
  bytes32 public constant ENABLER_ROLE = keccak256("ENABLER_ROLE");
  bool private accessControlInitialized;

  /**
   * @notice Initializes the upgradable contract.
   */
  function initializeAccessControl() external {
    require(!accessControlInitialized);
    accessControlInitialized = true;
    _grantRole(DEFAULT_ADMIN_ROLE, owner());
    _grantRole(ENABLER_ROLE, owner());
  }

  function enableTrade(address[] calldata nfts, bool[] calldata values) external onlyRole(ENABLER_ROLE) {
    require(nfts.length == values.length, "nfts and values have different length");

    for (uint256 i = 0; i < nfts.length; i++) {
      address nft = nfts[i];
      bool value = values[i];

      isNFTSupported[nft] = value;

      emit SupportNFTUpdated(nft, value);
    }
  }
}