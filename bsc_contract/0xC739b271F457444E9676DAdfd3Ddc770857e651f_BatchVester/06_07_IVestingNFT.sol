// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface IVestingNFT {
  function updateBaseURI(string memory _uri) external;

  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin
  ) external;

  function createLockedNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin,
    uint256 unlockDate,
    bool transferableNFTLockers
  ) external;

  function revokeNFTs(uint256[] memory tokenId) external;

  function redeemNFTs(uint256[] memory tokenId) external;

  function delegateTokens(address delegate, uint256[] memory tokenIds) external;

  function delegateAllNFTs(address delegate) external;

  function redeemAllNFTs() external;

  function streamBalanceOf(uint256 tokenId) external view returns (uint256 balance, uint256 remainder);

  function getStreamEnd(uint256 tokenId) external view returns (uint256 end);

  function streams(uint256 tokenId)
    external
    view
    returns (
      address token,
      uint256 amount,
      uint256 start,
      uint256 cliffDate,
      uint256 rate,
      address vestingAdmin,
      uint256 unlockDate,
      bool transferableNFTLockers
    );

  function balanceOf(address holder) external view returns (uint256 balance);

  function ownerOf(uint tokenId) external view returns (address);

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

  function tokenByIndex(uint256 index) external view returns (uint256);

  function balanceOfDelegate(address delegate) external view returns (uint256);

  function delegatedTo(uint256 tokenId) external view returns (address);

  function tokenOfDelegateByIndex(address delegate, uint256 index) external view returns (uint256);

  function lockedBalances(address holder, address token) external view returns (uint256);

  function delegatedBalances(address delegate, address token) external view returns (uint256);
}