// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketplaceV2.sol";
import "../RevenueSharing/RevenueSharingClaim.sol";

contract MarketplaceV3 is MarketplaceV2 {
  RevenueSharingClaim private _revenueSharingClaim;

  /**
   * @notice Emitted when the revenue sharing claim is updated.
   */
  event RevenueSharingClaimUpdated(RevenueSharingClaim revenueSharingClaim);

  /**
   * @notice Returns the revenue sharing claim.
   */
  function getRevenueSharingClaim() public view returns (RevenueSharingClaim) {
    return _revenueSharingClaim;
  }

  /**
   * @notice Sets the revenue sharing claim.
   * @param revenueSharingClaim Revenue sharing claim to set.
   */
  function setRevenueSharingClaim(RevenueSharingClaim revenueSharingClaim) public onlyOwner {
    _revenueSharingClaim = revenueSharingClaim;

    emit RevenueSharingClaimUpdated(revenueSharingClaim);
  }

  /**
   * @notice Executes a buy which is validated by a signature signed by the seller.
   * @param detail Detail object to use for the buy execution by the buyer.
   * @param signature Detail signature.
   */
  function buy(Detail calldata detail, bytes calldata signature, uint256 expiredAt, bytes calldata masterSignature) external nonReentrant {
    require(enabled == true, "buy is disabled");
    require(block.timestamp <= expiredAt, "signature is expired");
    require(alreadyUsed(detail.id) == false, "id already used");
    require(isSignatureValid(signature, keccak256(abi.encode(detail)), detail.seller), "invalid detail signature");
    require(isSignatureValid(masterSignature, keccak256(abi.encode(signature, expiredAt)), getMaster()), "invalid master signature");

    /**
     * @notice Transfers taxed bundle price from buyer to seller.
     */
    Price memory price = detail.price;
    uint256 feeAmount = (price.amount * fee.numerator) / fee.denominator;
    IERC20(price.tokenAddress).transferFrom(msg.sender, detail.seller, price.amount - feeAmount);

    // set revenue sharing claim rewards
    if (address(_revenueSharingClaim) != address(0)) {
      IERC20(price.tokenAddress).transferFrom(msg.sender, address(_revenueSharingClaim), feeAmount);
      _revenueSharingClaim.addReward(feeAmount);
    } else {
      IERC20(price.tokenAddress).transferFrom(msg.sender, address(this), feeAmount);
    }

    /**
     * @notice Transfers bundle from seller to buyer.
     */
    for (uint256 i = 0; i < detail.bundle.length; i++) {
      require(isNFTSupported[detail.bundle[i].tokenAddress], "nft address not supported");
      IERC721(detail.bundle[i].tokenAddress).safeTransferFrom(detail.seller, msg.sender, detail.bundle[i].tokenId);
    }

    setAlreadyUsed(detail.id, true);

    emit Buy(msg.sender, detail, signature);
  }
}