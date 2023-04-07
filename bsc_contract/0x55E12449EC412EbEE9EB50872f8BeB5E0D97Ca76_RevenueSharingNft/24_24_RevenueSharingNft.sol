// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./RevenueSharingClaim.sol";

struct OutputItem {
  uint256 tokenId;
}

/**
 * @title RevenueSharingNft
 * @dev RevenueSharingNft contract
 * @author Leo
 */
contract RevenueSharingNft is ERC721Enumerable, AccessControl {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  string private _tokenURI;
  uint256 private _maxSupply;

  RevenueSharingClaim private _revenueSharingClaim;

  /**
   * @dev Emitted when `maxSupply` is updated by `account`.
   */
  event MaxSupplyUpdated(uint256 maxSupply);

  /**
   * @dev Emitted when `tokenURI` is updated by `account`.
   */
  event TokenURIUpdated(string tokenURI);

  /**
   * @dev Emitted when `revenueSharingClaim` is updated by `account`.
   */
  event RevenueSharingClaimUpdated(RevenueSharingClaim revenueSharingClaim);

  /**
   * @dev constructor for RevenueSharingNft contract
   * @param name the name of the token
   * @param symbol the symbol of the token
   * @param tokenURI the tokenURI of the token
   * @param maxSupply the maxSupply of the token
   * @param revenueSharingClaim the RevenueSharingClaim contract
   */
  constructor(string memory name, string memory symbol, string memory tokenURI, uint256 maxSupply, RevenueSharingClaim revenueSharingClaim) ERC721(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);

    _tokenURI = tokenURI;

    _maxSupply = maxSupply;

    _revenueSharingClaim = revenueSharingClaim;
  }

  /**
   * @dev get maxSupply
   * @return maxSupply
   */
  function getMaxSupply() external view returns (uint256) {
    return _maxSupply;
  }

  /**
   * @dev update maxSupply
   * @param maxSupply the maxSupply of the token
   */
  function updateMaxSupply(uint256 maxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(maxSupply > this.totalSupply(), "RevenueSharing::updateMaxSupply: invalid maxSupply value");

    _maxSupply = maxSupply;

    emit MaxSupplyUpdated(maxSupply);
  }

  /**
   * @dev update tokenURI
   * @param tokenURI the tokenURI of the token
   */
  function updateTokenURI(string memory tokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _tokenURI = tokenURI;

    emit TokenURIUpdated(tokenURI);
  }

  /**
   * @dev get RevenueSharingClaim contract
   * @return RevenueSharingClaim contract
   */
  function getRevenueSharingClaim() external view returns (RevenueSharingClaim) {
    return _revenueSharingClaim;
  }

  /**
   * @dev set RevenueSharingClaim contract
   * @param revenueSharingClaim RevenueSharingClaim contract
   */
  function setRevenueSharingClaim(RevenueSharingClaim revenueSharingClaim) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revenueSharingClaim = revenueSharingClaim;

    emit RevenueSharingClaimUpdated(revenueSharingClaim);
  }

  /**
   * @dev batch mint
   * @param users the users to mint
   */
  function batchMint(address[] calldata users) external onlyRole(DEFAULT_ADMIN_ROLE) {
    for (uint256 i = 0; i < users.length; i++) {
      mint(users[i]);
    }
  }

  /**
   * @dev mint
   * @param user the user to mint
   * @return the id of the token
   */
  function mint(address user) public onlyRole(MINTER_ROLE) returns (uint256) {
    uint256 id = _tokenIds.current();

    require(id < _maxSupply, "RevenueSharing::mint: max supply reached");

    _revenueSharingClaim.updateLastClaimed(id);

    _tokenIds.increment();

    _safeMint(user, id);

    return id;
  }

  /**
   * @dev get baseURI of the token URI
   * @return baseURI
   */
  function _baseURI() internal view override returns (string memory) {
    return _tokenURI;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev get all items of user
   * @param user the user to get items
   * @return the items of user
   */
  function getAllItemsOfUser(address user) external view returns (OutputItem[] memory) {
    uint256 balance = balanceOf(user);
    OutputItem[] memory ids = new OutputItem[](balance);

    for (uint256 i = 0; i < balance; i++) {
      ids[i].tokenId = tokenOfOwnerByIndex(user, i);
    }

    return ids;
  }
}