// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
pragma abicoder v2;

import "../interfaces/interfaces.sol";
import "../interfaces/IPancakeFactoryV2.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title Launchpad
 * @author Planetarium
 */
contract Launchpad is Initializable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /// @notice Launchpad Operator
  address public LAUNCHPAD_OPERATOR;

   /// @notice WETH ADDRESS (WBNB in BSC Network)
  address private WETH_ADDRESS;

  /// @notice Pancake Swap Factory V2 Contract Address
  address private PANCAKE_FACTORY_V2_ADDRESS;

  /// @notice Project ID (PID)
  uint256 private projectID;

  /// @notice List of Projects
  mapping(uint256 => ProjectData) private PROJECTS;

  /* ========== EVENTS ========== */
  event ProjectInitialized(
    uint256 indexed _pid,
    address _commitCurrency,
    IERC20 _auctionToken,
    address _auctionTokenVault,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _totalOfferingTokens,
    uint256 _minCommitAmount,
    address _treasury,
    address _wallet,
    address _operator
  );
  event LaunchpadOperatorConfigured(address indexed _address);
  event AuctionOperatorConfigured(uint256 indexed _pid, address indexed _address);
  event AuctionTokenTransferredFromVault(uint256 indexed _pid);
  event ProjectCancelledBeforeStart(uint256 indexed _pid);
  event ProjectFinalized(uint256 indexed _pid);
  event UnclaimedAuctionTokenWithdrawn(uint256 indexed _pid);
  event UnclaimedLPTokenWithdrawn(uint256 indexed _pid);
  event AllowlistSignerChanged(uint256 indexed _pid, address indexed _address);
  event AllowlistCheckChanged(uint256 indexed _pid, bool _allowlistCheck);
  event CommitLimitConfigured(uint256 indexed _pid, uint256 _commitUserLimit, uint256 _commitTotalLimit);
  
  /**
   * @notice Launchpad Operator Modifier
   * @dev olny launchpad operator can init a project and set auction operator
   */
  modifier onlyLaunchpadOperator {
    require(msg.sender == LAUNCHPAD_OPERATOR, 'ONLY_LAUNCHPAD_OPERATOR');
    _;
  }

  /**
   * @notice Auction Operator Modifier
   * @dev only auction operator can manage the project
   */
  modifier onlyAuctionOperator(uint256 _pid) {
    require(msg.sender == PROJECTS[_pid].operator, 'ONLY_AUCTION_OPERATOR');
    _;
  }
 
  /**
   * @notice Check the project was initialized or not 
   */
  modifier isInitialized(uint256 _pid) {
    require(address(PROJECTS[_pid].auction) != address(0), 'PROJECT_SHOULD_BE_INITIALIZED');
    _;
  }

  /**
   * @notice Initializer of the launchpad contract
   * @param _launchpadOperator launchpad Operator
   * @param _wethAddress WETH Address
   * @param _PANCAKE_FACTORY_V2_ADDRESSAddress Pancake Swap Factory V2 Address
   */
  function initialize(
    address _launchpadOperator,
    address _wethAddress,
    address _PANCAKE_FACTORY_V2_ADDRESSAddress
  ) external initializer {
    LAUNCHPAD_OPERATOR = _launchpadOperator;
    WETH_ADDRESS = _wethAddress;
    PANCAKE_FACTORY_V2_ADDRESS = _PANCAKE_FACTORY_V2_ADDRESSAddress;

    // Project ID is initialized as 0
    projectID = 0;
  }

  /**
   * @notice Change Launchpad Operator
   * @param _launchpadOperator new launchpad opertor address
   */
  function changeLaunchpadOperator(address _launchpadOperator)
    external onlyLaunchpadOperator {
    require(_launchpadOperator != address(0), 'INVALID_ADDRESS');
    LAUNCHPAD_OPERATOR = _launchpadOperator;
    emit LaunchpadOperatorConfigured(_launchpadOperator);
  }

  /**
   * @notice Change Auction Operator for each projects
   * @param _auctionOperator auction opertor address
   */
  function changeAuctionOperator(uint256 _pid, address _auctionOperator)
    external isInitialized(_pid) onlyLaunchpadOperator {
    require(_auctionOperator != address(0), 'INVALID_ADDRESS');
    PROJECTS[_pid].operator = _auctionOperator;
    emit AuctionOperatorConfigured(_pid, _auctionOperator);
  }

  /**
   * @notice Initialize Project
   * @param _commitCurrency Commit currency address
   * @param _auctionToken Auction token to sale
   * @param _auctionTokenVault Auction token vault
   * @param _startTime Auction start time
   * @param _endTime Auction end time
   * @param _vestingPeriod Vesting Period
   * @param _claimablePeriod Claimable Period
   * @param _totalOfferingTokens Total Amount of Offering Tokens
   * @param _minCommitAmount Minimum Commitment Amount to success the auction
   * @param _treasury Treasury Wallet Address
   * @param _wallet Auction Wallet Address
   * @param _operator Operator of the auction
   */
  function initProject(
    address _commitCurrency,
    IERC20 _auctionToken,
    address _auctionTokenVault,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _vestingPeriod,
    uint256 _claimablePeriod,
    uint256 _totalOfferingTokens,
    uint256 _minCommitAmount,
    address _treasury,
    address payable _wallet,
    address _operator
  ) external onlyLaunchpadOperator returns (uint256) {

    // Create a new auction
    BatchAuction _auction = new BatchAuction(WETH_ADDRESS);

    // Initialize the auction with parameters
    _auction.initAuction(
      _commitCurrency,
      _auctionToken,
      _auctionTokenVault,
      _startTime,
      _endTime,
      _vestingPeriod,
      _claimablePeriod,
      _totalOfferingTokens,
      _minCommitAmount,
      _treasury,
      _wallet
    );

    // ProjectID starts from 1
    projectID += 1;
    PROJECTS[projectID].auction = _auction;
    PROJECTS[projectID].status = ProjectStatus.Initialized;
    PROJECTS[projectID].operator = _operator;

    emit ProjectInitialized(
      projectID,
      _commitCurrency,
      _auctionToken,
      _auctionTokenVault,
      _startTime,
      _endTime,
      _totalOfferingTokens,
      _minCommitAmount,
      _treasury,
      _wallet,
      _operator
    );

    return projectID;
  }

  /**
   * @notice Set Commit Limit
   * @param _pid Project ID
   * @param _commitUserLimit Commit Limit per User
   * @param _commitTotalLimit Commit Total Limit for the auction
   */
  function setCommitLimit(uint256 _pid, uint256 _commitUserLimit, uint256 _commitTotalLimit)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.setCommitLimit(_commitUserLimit, _commitTotalLimit);
    emit CommitLimitConfigured(_pid, _commitUserLimit, _commitTotalLimit);
  }

  /**
   * @notice Set Allowlist Signer
   * @param _pid Project ID
   * @param _signer Allowlist Signer Address
   */
  function setAllowlistSigner(uint256 _pid, address _signer)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.setAllowlistSigner(_signer);
    emit AllowlistSignerChanged(_pid, _signer);
  }

  /**
   * @notice Change Allowlist Check
   * @param _pid Project ID
   * @param _allowlistCheck Allowlist check is true or not
   */
  function changeAllowlistCheck(uint256 _pid, bool _allowlistCheck)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.changeAllowlistCheck(_allowlistCheck);
    emit AllowlistCheckChanged(_pid, _allowlistCheck);
  }

  /**
   * @notice Transfer Auction Token from Auction Token Vault
   * @param _pid Project ID
   */
  function transferAuctionTokenFromVault(uint256 _pid)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.transferAuctionTokenFromVault();
    emit AuctionTokenTransferredFromVault(_pid);
  }

  /**
   * @notice Cancel the project before start
   * @param _pid Project ID
   */
  function cancelProjectBeforeStart(uint256 _pid)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.cancelAuctionBeforeStart();
    PROJECTS[_pid].status = ProjectStatus.Cancelled;
    emit ProjectCancelledBeforeStart(_pid);
  }
  
  /**
   * @notice Finalize the project with Success
   * @param _pid Project ID
   * @param _lpTokenAddress LP Token Address
   * @param _minLP minimum LP value expected to be minted
   */
  function finalizeProjectWithSuccess(uint256 _pid, address _lpTokenAddress, uint256 _minLP)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.finalizeAuctionWithSuccess(_lpTokenAddress, _minLP);
    PROJECTS[_pid].status = ProjectStatus.Finalized;
    emit ProjectFinalized(_pid);
  }

  /**
   * @notice Finalize the project with Failure
   * @param _pid Project ID
   */
  function finalizeProjectWithFailure(uint256 _pid)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.finalizeAuctionWithFailure();
    PROJECTS[_pid].status = ProjectStatus.Finalized;
    emit ProjectFinalized(_pid);
  }

  /**
   * @notice Withdraw unclaimed auction token
   * @param _pid Project ID
   */
  function withdrawUnclaimedAuctionToken(uint256 _pid)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.withdrawUnclaimedAuctionToken();
    emit UnclaimedAuctionTokenWithdrawn(_pid);
  }

  /**
   * @notice Withdraw unclaimed LP token
   * @param _pid Project ID
   */
  function withdrawUnclaimedLPToken(uint256 _pid)
    external isInitialized(_pid) onlyAuctionOperator(_pid) {
    PROJECTS[_pid].auction.withdrawUnclaimedLPToken();
    emit UnclaimedLPTokenWithdrawn(_pid);
  }

  /* ========== EXTERNAL VIEWS ========== */
  /**
   * @notice Get Project Status
   * @param _pid Project ID
   */
  function getProjectStatus(uint256 _pid)
    external view isInitialized(_pid) returns (ProjectStatus) {
    return PROJECTS[_pid].status;
  }

  /**
   * @notice Get Auction Address
   * @param _pid Project ID
   */
  function getAuctionAddress(uint256 _pid)
    external view isInitialized(_pid) returns (address) {
    return address(PROJECTS[_pid].auction);
  }

  /**
   * @notice Get Pancake LP Token if the pool exists
   * @return LP Token Address
   */
  function getPancakeLPToken(address _token1, address _token2) external view returns (address) {
    require(_token1 != address(0), "INVALID_TOKEN1_ADDRESS");
    require(_token2 != address(0), "INVALID_TOKEN2_ADDRESS");
    return IPancakeFactoryV2(PANCAKE_FACTORY_V2_ADDRESS).getPair(_token1, _token2);
  }

  /**
   * @notice Create Pancake LP Token if the pool does not exist
   * @return LP Token Address
   */
  function createPancakeLPToken(address _token1, address _token2) external returns (address) {
    require(_token1 != address(0), "INVALID_TOKEN1_ADDRESS");
    require(_token2 != address(0), "INVALID_TOKEN2_ADDRESS");
    return IPancakeFactoryV2(PANCAKE_FACTORY_V2_ADDRESS).createPair(_token1, _token2);
  }
}