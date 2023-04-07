// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../common/Recoverable.sol";

interface IRevenueSharingNft {
  function totalSupply() external view returns (uint256);

  function mint(address user) external returns (uint256);
}

enum PriceType {
  BNB,
  ERC20
}

enum BuyType {
  SINGLE,
  BUNDLE
}

/**
 * @title RevenueSharingSale
 * @dev RevenueSharingSale contract
 * @author Leo
 */
contract RevenueSharingSale is Ownable, Recoverable, ReentrancyGuard, Pausable {
  IERC20 private _token;
  IRevenueSharingNft private _nft;

  uint private _itemSinglePrice;
  uint private _itemBundlePrice;
  uint private _mintLimit;
  uint private _bundleSize;

  PriceType private _priceType;

  /**
   * @dev Emitted when `user` buys `size` of items with `price`.
   */
  event ItemBought(address indexed user, BuyType buyType, uint size, uint price);

  /**
   * @dev Emitted when `priceType` is updated.
   */
  event PriceTypeUpdated(PriceType priceType);

  /**
   * @dev Emitted when `itemSinglePrice` is updated.
   */
  event SinglePriceUpdated(uint itemSinglePrice);

  /**
   * @dev Emitted when `itemBundlePrice` is updated.
   */
  event BundlePriceUpdated(uint itemBundlePrice);

  /**
   * @dev Emitted when `mintLimit` is updated.
   */
  event MintLimitUpdated(uint mintLimit);

  /**
   * @dev Emitted when `token` is updated.
   */
  event TokenUpdated(IERC20 token);

  /**
   * @dev Emitted when `bundleSize` is updated.
   */
  event BundleSizeUpdated(uint bundleSize);

  /**
   * @dev Emitted when `nft` is updated.
   */
  event NftUpdated(IRevenueSharingNft nft);

  /**
   * @dev constructor of RevenueSharingSale
   * @param token the token to be used for payment
   * @param nft the nft to be sold
   * @param priceType the price type of the sale
   * @param itemSinglePrice the price of a single item
   * @param itemBundlePrice the price of a bundle of items
   * @param mintLimit the limit of items to be sold
   */
  constructor(IERC20 token, IRevenueSharingNft nft, PriceType priceType, uint itemSinglePrice, uint itemBundlePrice, uint mintLimit, uint bundleSize) {
    _token = token;
    _nft = nft;
    _priceType = priceType;
    _itemSinglePrice = itemSinglePrice;
    _itemBundlePrice = itemBundlePrice;
    _mintLimit = mintLimit;
    _bundleSize = bundleSize;
  }

  /**
   * @dev returns the number of available items
   */
  function availableItems() public view returns (uint256) {
    return _mintLimit - _nft.totalSupply();
  }

  /**
   * @dev returns the price type of the sale
   * @return the price type of the sale
   */
  function getPriceType() external view returns (PriceType) {
    return _priceType;
  }

  /**
   * @dev returns the price of a single item
   * @return the price of a single item
   */
  function getItemSinglePrice() external view returns (uint) {
    return _itemSinglePrice;
  }

  /**
   * @dev returns the price of a bundle of items
   * @return the price of a bundle of items
   */
  function getItemBundlePrice() external view returns (uint) {
    return _itemBundlePrice;
  }

  /**
   * @dev returns the mint limit of the sale
   * @return the mint limit of the sale
   */
  function getMintLimit() external view returns (uint) {
    return _mintLimit;
  }

  /**
   * @dev returns the token of the sale
   * @return the token of the sale
   */
  function getToken() external view returns (IERC20) {
    return _token;
  }

  /**
   * @dev returns the nft of the sale
   * @return the nft of the sale
   */
  function getNft() external view returns (IRevenueSharingNft) {
    return _nft;
  }

  /**
   * @dev returns the bundle size of the sale
   * @return the bundle size of the sale
   */
  function getBundleSize() external view returns (uint) {
    return _bundleSize;
  }

  /**
   * @dev buys a single or a bundle of items
   * @param buyType the type of the buy either single or bundle
   */
  function buyItem(BuyType buyType) external payable nonReentrant whenNotPaused {
    require(availableItems() > 0, "RevenueSharingSale::buyItem: mint limit reached");

    uint size = buyType == BuyType.SINGLE ? 1 : _bundleSize;
    uint price = buyType == BuyType.SINGLE ? _itemSinglePrice : _itemBundlePrice;

    require(size <= availableItems(), "RevenueSharingSale::buyItem: not enough items available");

    if (_priceType == PriceType.BNB) {
      require(msg.value == price, "RevenueSharingSale::buyItem: bnb value is not correct");
    } else if (_priceType == PriceType.ERC20) {
      require(msg.value == 0, "RevenueSharingSale::buyItem: bnb value is not 0");
    }

    for (uint256 i = 0; i < size; i++) {
      _nft.mint(msg.sender);
    }

    if (_priceType == PriceType.ERC20) {
      _token.transferFrom(msg.sender, address(this), price);
    }

    emit ItemBought(msg.sender, buyType, size, price);
  }

  /**
   * @dev updates the price type of the sale
   * @param priceType the new price type of the sale
   */
  function updatePriceType(PriceType priceType) external onlyOwner {
    _priceType = priceType;

    emit PriceTypeUpdated(priceType);
  }

  /**
   * @dev updates the price of a single item
   * @param itemSinglePrice the new price of a single item
   */
  function updateSinglePrice(uint itemSinglePrice) external onlyOwner {
    _itemSinglePrice = itemSinglePrice;

    emit SinglePriceUpdated(itemSinglePrice);
  }

  /**
   * @dev updates the price of a bundle of items
   * @param itemBundlePrice the new price of a bundle of items
   */
  function updateBundlePrice(uint itemBundlePrice) external onlyOwner {
    _itemBundlePrice = itemBundlePrice;

    emit BundlePriceUpdated(itemBundlePrice);
  }

  /**
   * @dev updates the mint limit of the sale
   * @param mintLimit the new mint limit of the sale
   */
  function updateMintLimit(uint48 mintLimit) external onlyOwner {
    require(mintLimit >= _nft.totalSupply(), "RevenueSharingSale::updateMintLimit: mint limit is lower than total supply");

    _mintLimit = mintLimit;

    emit MintLimitUpdated(mintLimit);
  }

  /**
   * @dev updates the token of the sale
   * @param token the new token of the sale
   */
  function updateToken(IERC20 token) external onlyOwner {
    _token = token;

    emit TokenUpdated(token);
  }

  /**
   * @dev updates the nft of the sale
   * @param nft the new nft of the sale
   */
  function updateNft(IRevenueSharingNft nft) external onlyOwner {
    _nft = nft;

    emit NftUpdated(nft);
  }

  /**
   * @dev updates the bundle size of the sale
   * @param bundleSize the new bundle size of the sale
   */
  function updateBundleSize(uint48 bundleSize) external onlyOwner {
    _bundleSize = bundleSize;

    emit BundleSizeUpdated(bundleSize);
  }

  /**
   * @dev pauses the sale
   */
  function pause() external onlyOwner {
    _pause();

    emit Paused(msg.sender);
  }

  /**
   * @dev unpauses the sale
   */
  function unpause() external onlyOwner {
    _unpause();

    emit Unpaused(msg.sender);
  }

  /**
   * @dev returns the minimum of two numbers
   * @param a the first number
   * @param b the second number
   * @return the minimum of the two numbers
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}