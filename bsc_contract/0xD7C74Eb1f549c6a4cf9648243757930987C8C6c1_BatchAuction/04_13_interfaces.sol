// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "../launchpad/BatchAuction.sol";

/**
 * @dev Asset Data
 */
struct AssetData {
  uint128 emissionPerSecond;
  uint128 lastUpdateTimestamp;
  uint256 index;
  mapping(address => uint256) users;
}

/**
 * @dev Auction Data
 */
struct AuctionData {
  uint256 startTime;
  uint256 endTime;
  uint256 totalOfferingTokens;
  uint256 totalLPTokenAmount;
  uint256 minCommitmentsAmount;
  uint256 totalCommitments;
  bool finalized;
}

/// @notice Project Status
enum ProjectStatus {
  Initialized,
  Cancelled,
  Finalized
}

/// @notice Project Data
struct ProjectData {
  BatchAuction auction; 
  ProjectStatus status;
  address operator;
}