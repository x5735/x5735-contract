// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import "../interfaces/chainlink/AggregatorV3Interface.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {Helpers} from "../utils/Helpers.sol";
import "hardhat/console.sol";

abstract contract OracleRouterBase is IOracle {
  /**
   * @dev The price feed contract to use for a particular asset.
   * @param asset address of the asset
   * @return address address of the price feed for the asset
   */
  function feed(address asset) internal view virtual returns (address);

  /**
   * @notice Returns the total price in 8 digit USD for a given asset.
   * @param asset address of the asset
   * @return uint256 USD price of 1 of the asset, in 8 decimal fixed
   */
  function price(address asset) external view override returns (uint256) {
    address _feed = feed(asset);
    //require(_feed != address(0), "Asset not available: Price");
    (, int256 _iprice, , , ) = AggregatorV3Interface(_feed).latestRoundData();
    uint256 _price = uint256(_iprice);
    return uint256(_price);
  }
}

contract OracleRouter is OracleRouterBase {
  /**
   * @dev The price feed contract to use for a particular asset.
   * @param asset address of the asset
   */
  function feed(address asset) internal pure override returns (address) {
    if (asset == address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270)) {
      // polygon
      // ? Chainlink: WMATIC/USDC
      return address(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
    } else if (asset == address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)) {
      // BSC
      return address(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
    } else if (asset == address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)) {
      // arbitrum
      return address(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
    } else if (asset == address(0x4200000000000000000000000000000000000006)) {
      // optimism
      return address(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    } else {
      revert("Asset not available");
    }
  }
}

contract OracleRouterDev is OracleRouterBase {
  mapping(address => address) public assetToFeed;

  function setFeed(address _asset, address _feed) external {
    assetToFeed[_asset] = _feed;
  }

  /**
   * @dev The price feed contract to use for a particular asset.
   * @param asset address of the asset
   */
  function feed(address asset) internal view override returns (address) {
    return assetToFeed[asset];
  }
}