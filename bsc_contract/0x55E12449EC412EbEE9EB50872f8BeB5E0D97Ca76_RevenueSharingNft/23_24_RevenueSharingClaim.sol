// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../common/Recoverable.sol";

/**
 * @title RevenueSharingClaim
 * @dev RevenueSharingClaim contract
 * @author Leo
 */
contract RevenueSharingClaim is AccessControl, ReentrancyGuard, Pausable, Recoverable {
  using SafeERC20 for IERC20;

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

  IERC20 private _rewardToken;
  ERC721Enumerable private _revenueNft;

  uint256 private _rewardPerNft;

  /**
   * @dev last claimed amount for each token
   * @dev tokenId => last claimed amount
   */
  mapping(uint256 => uint256) private _lastClaimed;

  /**
   * @dev Emitted when `amount` of reward is added to the contract with `supply` of revenue token.
   */
  event RewardAdded(address indexed manager, uint256 amount, uint256 supply);

  /**
   * @dev Emitted when `amount` of reward is claimed by `user` for `tokenId`.
   */
  event RewardClaimed(uint256 tokenId, address user, uint256 amount);

  /**
   * @dev Emitted when `tokenId`'s last claimed amount is updated to `amount`.
   */
  event LastClaimedUpdated(uint256 tokenId, uint256 amount);

  /**
   * @dev Emitted when `rewardToken` is updated by `account`.
   */
  event RewardTokenUpdated(address rewardToken);

  /**
   * @dev Emitted when `revenueNft` is updated by `account`.
   */
  event RevenueNftUpdated(address revenueNft);

  /**
   * @dev Initializes the contract by setting a `rewardToken` and a `revenueNft`.
   */
  constructor(IERC20 rewardToken, ERC721Enumerable revenueNft) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MANAGER_ROLE, _msgSender());
    _setupRole(MARKETPLACE_ROLE, _msgSender());

    _rewardToken = rewardToken;
    _revenueNft = revenueNft;
  }

  /**
   * @dev add reward to the contract
   * @param amount the amount of reward to add
   */
  function addReward(uint256 amount) external onlyRole(MARKETPLACE_ROLE) {
    uint256 supply = _revenueNft.totalSupply();
    _rewardPerNft += amount / supply;

    emit RewardAdded(msg.sender, amount, supply);
  }

  /**
   * @dev get reward per token
   * @return reward per token
   */
  function getRewardPerNft() external view returns (uint256) {
    return _rewardPerNft;
  }

  /**
   * @dev get last claimed amount
   * @param tokenId the token id
   * @return last claimed amount
   */
  function getLastClaimed(uint256 tokenId) external view returns (uint256) {
    return _lastClaimed[tokenId];
  }

  /**
   * @dev get reward token
   * @return reward token
   */
  function getRewardToken() external view returns (IERC20) {
    return _rewardToken;
  }

  /**
   * @dev set reward token
   * @param rewardToken the reward token
   */
  function setRewardToken(IERC20 rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _rewardToken = rewardToken;

    emit RewardTokenUpdated(address(rewardToken));
  }

  /**
   * @dev get revenue token
   * @return revenue token
   */
  function getRevenueNft() external view returns (ERC721Enumerable) {
    return _revenueNft;
  }

  /**
   * @dev set revenue token
   * @param revenueNft the revenue token
   */
  function setRevenueNft(ERC721Enumerable revenueNft) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revenueNft = revenueNft;

    emit RevenueNftUpdated(address(revenueNft));
  }

  /**
   * @dev get claimable amount
   * @param tokenId the token id
   * @return claimable amount
   */
  function claimable(uint256 tokenId) public view returns (uint256) {
    if (_lastClaimed[tokenId] >= _rewardPerNft) {
      return 0;
    }

    return _rewardPerNft - _lastClaimed[tokenId];
  }

  /**
   * @dev get claimable amount for multiple tokenIds
   * @param tokenIds the token ids
   * @return claimable amount for each tokenId
   */
  function batchClaimable(uint256[] calldata tokenIds) external view returns (uint256[] memory) {
    uint256[] memory claimables = new uint256[](tokenIds.length);

    for (uint256 i = 0; i < tokenIds.length; i++) {
      claimables[i] = claimable(tokenIds[i]);
    }

    return claimables;
  }

  /**
   * @dev update last claimed amount
   * @param tokenId the token id
   */
  function updateLastClaimed(uint256 tokenId) public onlyRole(MANAGER_ROLE) {
    _updateLastClaimed(tokenId);
  }

  /**
   * @dev update last claimed amount
   * @param tokenId the token id
   */
  function _updateLastClaimed(uint256 tokenId) internal {
    _lastClaimed[tokenId] = _rewardPerNft;

    emit LastClaimedUpdated(tokenId, _rewardPerNft);
  }

  /**
   * @dev claim reward
   * @param tokenId the token id
   */
  function claimReward(uint256 tokenId) public nonReentrant whenNotPaused {
    require(_revenueNft.ownerOf(tokenId) == msg.sender, "RevenueClaiming::claimReward: caller is not the token owner");
    require(_rewardPerNft > _lastClaimed[tokenId], "RevenueClaiming::claimReward: no reward to claim");

    uint256 claim = claimable(tokenId);
    require(claim > 0, "RevenueClaiming::claimReward: no reward to claim");

    _updateLastClaimed(tokenId);

    _rewardToken.safeTransfer(msg.sender, claim);

    emit RewardClaimed(tokenId, msg.sender, claim);
  }

  /**
   * @dev claim reward for multiple tokenIds
   * @param tokenIds the token ids
   */
  function batchClaimReward(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      claimReward(tokenIds[i]);
    }
  }

  /**
   * @dev pause the contract
   */
  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  /**
   * @dev unpause the contract
   */
  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }
}