// SPDX-License-Identifier: UNLICENSED

/**
 * ¨€¨€¨€¨[   ¨€¨€¨€¨[ ¨€¨€¨€¨€¨€¨€¨[  ¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨€¨[   ¨€¨€¨[    ¨€¨€¨[      ¨€¨€¨€¨€¨€¨[ ¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨€¨€¨€¨€¨€¨[
 * ¨€¨€¨€¨€¨[ ¨€¨€¨€¨€¨U¨€¨€¨X¨T¨T¨T¨€¨€¨[¨€¨€¨X¨T¨T¨T¨€¨€¨[¨€¨€¨€¨€¨[  ¨€¨€¨U    ¨€¨€¨U     ¨€¨€¨X¨T¨T¨€¨€¨[¨€¨€¨X¨T¨T¨€¨€¨[¨€¨€¨X¨T¨T¨T¨T¨a
 * ¨€¨€¨X¨€¨€¨€¨€¨X¨€¨€¨U¨€¨€¨U   ¨€¨€¨U¨€¨€¨U   ¨€¨€¨U¨€¨€¨X¨€¨€¨[ ¨€¨€¨U    ¨€¨€¨U     ¨€¨€¨€¨€¨€¨€¨€¨U¨€¨€¨€¨€¨€¨€¨X¨a¨€¨€¨€¨€¨€¨€¨€¨[
 * ¨€¨€¨U¨^¨€¨€¨X¨a¨€¨€¨U¨€¨€¨U   ¨€¨€¨U¨€¨€¨U   ¨€¨€¨U¨€¨€¨U¨^¨€¨€¨[¨€¨€¨U    ¨€¨€¨U     ¨€¨€¨X¨T¨T¨€¨€¨U¨€¨€¨X¨T¨T¨€¨€¨[¨^¨T¨T¨T¨T¨€¨€¨U
 * ¨€¨€¨U ¨^¨T¨a ¨€¨€¨U¨^¨€¨€¨€¨€¨€¨€¨X¨a¨^¨€¨€¨€¨€¨€¨€¨X¨a¨€¨€¨U ¨^¨€¨€¨€¨€¨U    ¨€¨€¨€¨€¨€¨€¨€¨[¨€¨€¨U  ¨€¨€¨U¨€¨€¨€¨€¨€¨€¨X¨a¨€¨€¨€¨€¨€¨€¨€¨U
 * ¨^¨T¨a     ¨^¨T¨a ¨^¨T¨T¨T¨T¨T¨a  ¨^¨T¨T¨T¨T¨T¨a ¨^¨T¨a  ¨^¨T¨T¨T¨a    ¨^¨T¨T¨T¨T¨T¨T¨a¨^¨T¨a  ¨^¨T¨a¨^¨T¨T¨T¨T¨T¨a ¨^¨T¨T¨T¨T¨T¨T¨a
 *
 * Moon Labs LLC reserves all rights on this code.
 * You may not, except otherwise with prior permission and express written consent by Moon Labs LLC, copy, download, print, extract, exploit,
 * adapt, edit, modify, republish, reproduce, rebroadcast, duplicate, distribute, or publicly display any of the content, information, or material
 * on this smart contract for non-personal or commercial purposes, except for any other use as permitted by the applicable copyright law.
 *
 * Website: https://www.moonlabs.site/
 */

/**
 * @title This is a contract used for creating whitelists for Moon Labs products
 * @author Moon Labs LLC
 * @notice  This contract's intended purpose is for users to purchase whitelists for their desired tokens. Whitelisting a token allows for all fees on
 * related Moon Labs products to be waived. Whitelists may not be transferred from token to token.
 */

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./IDEXRouter.sol";

interface IMoonLabsReferral {
  function checkIfActive(string calldata code) external view returns (bool);

  function getAddressByCode(string memory code) external view returns (address);

  function addRewardsEarnedUSD(string calldata code, uint commission) external;
}

interface IMoonLabsWhitelist {
  function getIsWhitelisted(address _address) external view returns (bool);
}

contract MoonLabsWhitelist is Initializable, IMoonLabsWhitelist, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  function initialize(address _mlabToken, address _feeCollector, address referralAddress, address usdAddress, address routerAddress, uint _costUSD) public initializer {
    __Ownable_init();
    feeCollector = _feeCollector;
    costUSD = _costUSD;
    mlabToken = IERC20Upgradeable(_mlabToken);
    usdContract = IERC20Upgradeable(usdAddress);
    routerContract = IDEXRouter(routerAddress);
    referralContract = IMoonLabsReferral(referralAddress);
    codeDiscount = 10;
    codeCommission = 10;
    mlabDiscountPercent = 20;
  }

  /*|| === STATE VARIABLES === ||*/
  uint public costUSD; /// Cost in USD
  address public feeCollector; /// Fee collection address for paying with token percent
  uint32 public codeDiscount; /// Discount in the percentage applied to the customer when using referral code, represented in 10s
  uint32 public codeCommission; /// Percentage of each lock purchase sent to referral code owner, represented in 10s
  uint8 public mlabDiscountPercent; /// Percent discount of MLAB pruchases
  IERC20Upgradeable public mlabToken; /// Native Moon Labs token
  IERC20Upgradeable public usdContract; /// Select USD contract
  IMoonLabsReferral public referralContract; /// Moon Labs referral contract
  IDEXRouter public routerContract; /// Uniswap router

  /*|| === MAPPINGS === ||*/
  mapping(address => bool) tokenToWhitelist;
  mapping(address => bool) pairToBlacklist;

  /*|| === EXTERNAL FUNCTIONS === ||*/
  /**
   * @notice Purchase a whitelist for a single token.
   * @param _address Token address to be whitelisted
   */
  function purchaseWhitelistMLAB(address _address) external {
    /// Check if token is already whitelisted
    require(!tokenToWhitelist[_address], "Token already whitelisted");

    _buyWithMLAB(costUSD);

    tokenToWhitelist[_address] = true;
  }

  /**
   * @notice Purchase a whitelist for a single token.
   * @param _address Token address to be whitelisted
   */
  function purchaseWhitelist(address _address) external {
    /// Check if token is already whitelisted
    require(!tokenToWhitelist[_address], "Token already whitelisted");
    /// Check for significant balance
    require(usdContract.balanceOf(msg.sender) >= costUSD, "Insignificant balance");

    usdContract.safeTransferFrom(msg.sender, address(this), costUSD);
    /// Add token to global whitelist
    tokenToWhitelist[_address] = true;
  }

  /**
   * @notice Purchase a whitelist for a single token using a referral code.
   * @param _address Token address to be whitelisted
   * @param code Referral code
   */
  function purchaseWhitelistWithCode(address _address, string calldata code) external {
    /// Check if token is already whitelisted
    require(!tokenToWhitelist[_address], "Token already whitelisted");
    /// Check for valid code
    require(referralContract.checkIfActive(code), "Invalid code");
    /// Check for significant balance
    require(usdContract.balanceOf(msg.sender) >= costUSD - (costUSD * codeDiscount) / 100, "Insignificant balance");
    /// Transfer tokens from caller to contract
    usdContract.safeTransferFrom(msg.sender, address(this), costUSD - (costUSD * codeDiscount) / 100);
    /// Distribute commission to code owner
    _distributeCommission(code, (costUSD * codeCommission) / 100);
    /// Add token to global whitelist
    tokenToWhitelist[_address] = true;
  }

  /**
   * @notice Add to whitelist without fee. Owner only function.
   * @param _address Token address to be whitelisted
   */
  function ownerWhitelistAdd(address _address) external onlyOwner {
    /// Check if token is already whitelisted
    require(!tokenToWhitelist[_address], "Token already whitelisted");
    tokenToWhitelist[_address] = true;
  }

  /**
   * @notice Remove from whitelist. Owner only function.
   * @param _address Token address to be removed from whitelist
   */
  function removeWhitelist(address _address) external onlyOwner {
    /// Check if token whitelisted
    require(tokenToWhitelist[_address], "Token not whitelisted");
    tokenToWhitelist[_address] = false;
  }

  /**
   * @notice Add token to pair blacklist. Owner only function.
   * @param _address Token address to be blacklisted
   */
  function addPairBlacklist(address _address) external onlyOwner {
    /// Check if token is already blacklisted
    require(!pairToBlacklist[_address], "Token already blacklisted");
    pairToBlacklist[_address] = true;
  }

  /**
   * @notice Remove token from pair blacklist. Owner only function.
   * @param _address Token address to be removed from blacklist
   */
  function removePairBlacklist(address _address) external onlyOwner {
    /// Check if token is already blacklisted
    require(pairToBlacklist[_address], "Token not blacklisted");
    pairToBlacklist[_address] = false;
  }

  /**
   * @notice Set the cost of each whitelist purchase. Owner only function
   * @param _costUSD Cost per whitelist
   */
  function setCostUSD(uint _costUSD) external onlyOwner {
    costUSD = _costUSD;
  }

  /**
   * @notice Set the percentage of ETH per lock discounted on code use. Owner only function.
   * @param _codeDiscount Percentage represented in 10s
   */
  function setCodeDiscount(uint8 _codeDiscount) external onlyOwner {
    require(_codeDiscount < 100, "Percentage ceiling");
    codeDiscount = _codeDiscount;
  }

  /**
   * @notice Set the fee collection address. Owner only function.
   * @param _feeCollector Address of the fee collector
   */
  function setFeeCollector(address _feeCollector) external onlyOwner {
    require(_feeCollector != address(0), "Zero Address");
    feeCollector = _feeCollector;
  }

  /**
   * @notice Set the percentage of ETH per lock distributed to the code owner. Owner only function.
   * @param _codeCommission Percentage represented in 10s
   */
  function setCodeCommission(uint8 _codeCommission) external onlyOwner {
    require(_codeCommission < 100, "Percentage ceiling");
    codeCommission = _codeCommission;
  }

  /**
   * @notice Set the referral contract address. Owner only function.
   * @param _referralAddress Address of Moon Labs referral address
   */
  function setReferralContract(address _referralAddress) external onlyOwner {
    require(_referralAddress != address(0), "Zero Address");
    referralContract = IMoonLabsReferral(_referralAddress);
  }

  /**
   * @notice Set the Uniswap router address. Owner only function.
   * @param _routerAddress Address of uniswap router
   */
  function setRouter(address _routerAddress) external onlyOwner {
    require(_routerAddress != address(0), "Zero Address");
    routerContract = IDEXRouter(_routerAddress);
  }

  /**
   * @notice Set the USD token address. Owner only function.
   * @param _usdAddress USD token address
   */
  function setUSDContract(address _usdAddress) external onlyOwner {
    require(_usdAddress != address(0), "Zero Address");
    usdContract = IERC20Upgradeable(_usdAddress);
  }

  /**
   * @notice Set the Moon Labs native token address. Owner only function.
   * @param _mlabToken native moon labs token
   */
  function setMlabToken(address _mlabToken) external onlyOwner {
    require(_mlabToken != address(0), "Zero Address");
    mlabToken = IERC20Upgradeable(_mlabToken);
  }

  /**
   * @notice Set the percentage of MLAB discounted per lock. Owner only function.
   * @param _mlabDiscountPercent Percentage represented in 10s
   */
  function setMlabDiscountPercent(uint8 _mlabDiscountPercent) external onlyOwner {
    require(_mlabDiscountPercent < 100, "Percentage ceiling");
    mlabDiscountPercent = _mlabDiscountPercent;
  }

  /**
   * @notice Send all eth in contract to caller. Owner only function.
   */
  function claimETH() external onlyOwner {
    (bool sent, ) = payable(msg.sender).call{ value: address(this).balance }("");
    require(sent, "Failed to send Ether");
  }

  /**
   * @notice Send all USD in contract to caller. Owner only function.
   */
  function claimUSD() external onlyOwner {
    usdContract.safeTransferFrom(address(this), msg.sender, usdContract.balanceOf(address(this)));
  }

  function getTokenToWhitelist(address _address) external view returns (bool) {
    return tokenToWhitelist[_address];
  }

  function getPairToBlacklist(address _address) external view returns (bool) {
    return pairToBlacklist[_address];
  }

  /*|| === PUBLIC FUNCTIONS === ||*/
  /**
   * @notice Check to see if a token is whitelisted.
   * @param _address Token address to check if whitelisted
   */
  function getIsWhitelisted(address _address) public view override returns (bool) {
    if (tokenToWhitelist[_address]) return true;
    /// Check for v2 pairs
    if (_checkV2Pair(_address)) return true;
    /// Check for v3 pools
    if (_checkV3Pool(_address)) return true;
    return false;
  }

  /**
   * @notice Fetches price of mlab to WETH
   * @param amountInUSD amount in USD
   */
  function getMLABFee(uint amountInUSD) public view returns (uint) {
    ///  Get price quote via uniswap router
    address[] memory pathUSD = new address[](2);
    pathUSD[0] = address(usdContract);
    pathUSD[1] = routerContract.WETH();
    uint[] memory amountOutsUSD = routerContract.getAmountsOut(amountInUSD, pathUSD);
    ///  Get price quote via uniswap router
    address[] memory pathMLAB = new address[](2);
    pathMLAB[0] = routerContract.WETH();
    pathMLAB[1] = address(mlabToken);
    uint[] memory amountOutsMLAB = routerContract.getAmountsOut(amountOutsUSD[1], pathMLAB);
    return MathUpgradeable.mulDiv(amountOutsMLAB[1], (100 - mlabDiscountPercent), 100);
  }

  /*|| === PRIVATE FUNCTIONS === ||*/
  /**
   * @notice Private function purchases with mlab
   */
  function _buyWithMLAB(uint amountInUSD) private {
    /// Fee in MLAB
    uint mlabFee = getMLABFee(amountInUSD);
    /// Check for adequate supply in sender wallet
    require(mlabFee <= mlabToken.balanceOf(msg.sender), "MLAB balance");

    /// Transfer tokens from sender to fee collector
    mlabToken.safeTransferFrom(msg.sender, feeCollector, mlabFee);
  }

  /**
   * @notice Distribute commission to referral code owner.
   * @param code Referral code used
   * @param commission Amount in USD tokens to be distributed
   */
  function _distributeCommission(string calldata code, uint commission) private {
    /// Get balance before sending tokens
    uint previousBal = usdContract.balanceOf(address(this));

    /// Send USD to referral code owner
    usdContract.safeTransfer(referralContract.getAddressByCode(code), commission);

    /// Calculate amount sent based off before and after balance
    uint amountSent = usdContract.balanceOf(address(this)) - previousBal;

    /// Log rewards in the referral contract
    referralContract.addRewardsEarnedUSD(code, amountSent);
  }

  /**
   * @notice Checks if address is v2 pair and if pair is linked to whitelisted token
   * @param _address address to check
   */
  function _checkV2Pair(address _address) private view returns (bool) {
    /// Check if address is contract
    if (_address.code.length == 0) {
      return false;
    }
    /// Check if address is v2 pair address to whitelisted token
    IUniswapV2Pair pairContract = IUniswapV2Pair(_address);

    try pairContract.token0() returns (address _token0) {
      if (_checkIfValidPair(_token0)) return true;
    } catch (bytes memory) {
      return false;
    }
    try pairContract.token1() returns (address _token1) {
      if (_checkIfValidPair(_token1)) return true;
    } catch (bytes memory) {
      return false;
    }
    return false;
  }

  /**
   * @notice Checks if address is v3 pair and if pair is linked to whitelisted token
   * @param _address address to check
   */
  function _checkV3Pool(address _address) private view returns (bool) {
    /// Check if address is contract
    if (_address.code.length == 0) {
      return false;
    }

    /// Check if address is v3 pool address to whitelisted token
    IUniswapV3Pool poolContract = IUniswapV3Pool(_address);

    try poolContract.token0() returns (address _token0) {
      if (_checkIfValidPair(_token0)) return true;
    } catch (bytes memory) {
      return false;
    }
    try poolContract.token1() returns (address _token1) {
      if (_checkIfValidPair(_token1)) return true;
    } catch (bytes memory) {
      return false;
    }
    return false;
  }

  /**
   * @notice Checks if address is whitelisted and if pair is not blacklisted
   * @param _address address to check
   */
  function _checkIfValidPair(address _address) private view returns (bool) {
    if (tokenToWhitelist[_address] && !pairToBlacklist[_address]) return true;
    return false;
  }
}