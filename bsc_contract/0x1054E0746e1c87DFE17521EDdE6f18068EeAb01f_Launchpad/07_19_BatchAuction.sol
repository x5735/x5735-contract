// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
pragma abicoder v2;

import "../interfaces/interfaces.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BatchAuction
 * @author Planetarium
 */
contract BatchAuction is Ownable, ReentrancyGuard {
  using ECDSA for bytes32;
  using Math for uint256;
  using SafeERC20 for IERC20;

  /// @notice The auction token to sale
  IERC20 public AUCTION_TOKEN;

  /// @notice Auction Token Vault Address
  address public AUCTION_TOKEN_VAULT;

  /// @notice Where the auction funds will be transferred
  address payable public AUCTION_WALLET;

  /// @notice Auction Treasury Address
  address public AUCTION_TREASURY;

  /// @notice Amount of commitments per user
  mapping(address => uint256) private COMMITMENTS;

  /// @notice Amount of accumulated commitments per user
  mapping(address => uint256) private ACCUMULATED_COMMITMENTS;

  /// @notice Amount of accumulated withdrawals per user
  mapping(address => uint256) private ACCUMULATED_WITHDRAWALS;

  /// @notice To check if the user participated
  mapping(address => bool) private PARTICIPATED;

  /// @notice To count number of participants
  uint256 public numOfParticipants;

  /// @notice Amount of vested token claimed per user
  mapping(address => uint256) private VESTED_LPTOKEN_CLAIMED;

  /// @notice To check the user claimed instant token or not
  mapping(address => bool) private USER_RECEIVED_INSTANT_TOKEN;

  /// @notice Auction Data
  AuctionData private auctionData;

  /// @notice Withdraw cap variables
  uint256 private WITHDRAW_CAP_MIN;
  uint256 private WITHDRAW_CAP_MAX;
  uint256 private WITHDRAW_CAP_LIMIT;
  uint256 private WITHDRAW_CAP_INTERCEPT;
  uint256 private WITHDRAW_CAP_INTERCEPT_PLUS;
  uint256 private WITHDRAW_CAP_INTERCEPT_DIV;

  /// @notice Vesting period in second, 60 days => 5184000 seconds
  uint256 public VESTING_PERIOD;

  /// @notice Token claim period in second, 90 days => 7776000 seconds
  uint256 public CLAIMABLE_PERIOD;

  /// @notice To check commit currency is ETH(BNB) or ERC20 token
  address public COMMIT_CURRENCY;

  /// @notice Commit Limit per user
  uint256 public COMMIT_USER_LIMIT;

  /// @notice Commit Total Cap
  uint256 public COMMIT_TOTAL_LIMIT;

  /// @notice ETH Address (ETH is BNB in BSC network)
  address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice WETH Address (WETH is WBNB in BSC Network)
  address private WETH_ADDRESS;

  /// @notice PancakeSwap LP Token
  address public PANCAKE_LPTOKEN;

  /// @notice Allowlist check or not
  bool public ALLOWLIST_CHECK;

  /// @notice Allowlist Signer
  address private ALLOWLIST_SIGNER;

  /// @notice name for creating domain separator
  string public constant name = 'BatchAuction V1';

  /// @notice domain separator
  bytes32 public DOMAIN_SEPARATOR;

  /* ========== EVENTS ========== */
  event AuctionInitialized(
    address _commitCurrency,
    IERC20 _auctionToken,
    address _auctionTokenVault,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _totalOfferingTokens,
    uint256 _minimumCommitmentAmount,
    address _treasury,
    address _wallet
  );
  event CommitLimitConfigured(uint256 _commitUserLimit, uint256 _commitTotalLimit);
  event AllowlistSignerConfigured(address indexed _addr);
  event AllowlistCheckConfigured(bool _allowlistCheck);
  event ETHCommitted(address indexed _user, uint256 _amount);
  event TokenCommitted(address indexed _user, uint256 _amount);
  event CommitmentAdded(address indexed _user, uint256 _amount);
  event CommitmentWithdrawn(address indexed _user, uint256 _amount);
  event InstantTokenClaimed(address indexed _user, uint256 _amount, uint256 _userCommitments);
  event VestedLPTokenClaimed(address indexed _user, uint256 _amount);
  event ETHWithdrawn(address indexed _user, uint256 _amount);
  event ERC20TokenWithdrawan(address indexed _user, uint256 _amount);
  event UnclaimedTokenWithdrawan(address indexed _treasury, uint256 _amount);
  event UnclaimedLPTokenWithdrawn(address indexed _treasury, uint256 _amount);
  event GotCommitmentBack(address indexed _user, uint256 _amount);
  event AuctionTokenTransferredFromVault(address indexed _vault, uint256 _amount);
  event AuctionCancelled();
  event FinalizedAuctionWithFailure(uint256 _totalOfferingTokens);
  event FinalizedAuctionWithSuccess(
    uint256 _transferAmount,
    uint256 _token1Amount,
    uint256 _token2Amount,
    address _lpTokenAddress,
    uint256 _lpTokenAmount
  );
  event PancakeSwapPoolCreated(
    address _lpTokenAddress,
    uint256 _token1Amount,
    uint256 _token2Amount,
    uint256 _lpTokenAmount
  );

  /* ========== CONSTRUCTOR ========== */
  constructor(address _wethAddress) {
    WETH_ADDRESS = _wethAddress;

    /**
     * @dev creating DOMAIN_SEPARATOR
     * Reference: https://eips.ethereum.org/EIPS/eip-2612
     */
    uint chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(bytes(name)),
        keccak256(bytes('1')),
        chainId,
        address(this)
      )
    );

    /// @dev Allowlist check is true by default
    ALLOWLIST_CHECK = true;
  }

  /* ========== MODIFIERS ========== */
  /**
   * @notice only Auction Window
   */
  modifier isAuctionWindow {
    require(auctionData.startTime < block.timestamp 
            && block.timestamp < auctionData.endTime, "INVALID_AUCTION_TIME");
    require(!auctionData.finalized, "AUCTION_SHOULD_NOT_BE_FINALIZED"); 
    _;
  }

  /**
   * @notice Is Valid Claimable Period
   */
  modifier isClaimablePeriod {
    require(_isValidClaimablePeriod(), "INVALID_CLAIMABLE_PERIOD");
    _;
  }

  /**
   * @notice Is Claimable Period Ended
   */
  modifier isClaimablePeriodEnded {
    require((auctionData.endTime + CLAIMABLE_PERIOD) < block.timestamp, "CLAIMABLE_PERIOD_NOT_ENDED");
    _;
  }

  /**
   * @notice Is Auction Finalized With Success
   */
  modifier isAuctionFinalizedWithSuccess {
    require(auctionData.endTime < block.timestamp, "AUCTION_NOT_ENDED");
    require(isAuctionSuccessful(), "AUCTION_SHOULD_BE_SUCCESSFUL");
    require(auctionData.finalized, "AUCTION_SHOULD_BE_FINALIZED");
    _;
  }

  /**
   * @notice User can commitment back
   */
  modifier canCommitmentBack {
    require(auctionData.endTime < block.timestamp, "AUCTION_NOT_ENDED");
    require(!isAuctionSuccessful(), "AUCTION_SHOULD_BE_FAILED");
    require(auctionData.finalized, "AUCTION_SHOULD_BE_FINALIZED"); 
    require(COMMIT_CURRENCY != address(0), "INVALID_COMMIT_CURRENCY");
    _;
  }

  /**
   * @notice Operator can finalize the auction
   */
  modifier canFinalizeAuction {
    require(auctionData.endTime < block.timestamp, "AUCTION_NOT_ENDED");
    require(auctionData.totalOfferingTokens > 0, "NOT_INITIALIZED");
    require(!auctionData.finalized, "AUCTION_SHOULD_NOT_BE_FINALIZED"); 
    _;
  }

  /**
   * @notice can claim vested LP Tokens
   * @param _user Address of the user
   */
  modifier canClaimVestedLPToken(address _user) {
    require(COMMITMENTS[_user] > 0, "NO_COMMITMENTS");
    require(_isValidClaimablePeriod(), "INVALID_CLAIMABLE_PERIOD");
    _;
  }

  /**
   * @notice Set Commit User Limit & Total Limit
   * @param _commitUserLimit Commit User Limit
   * @param _commitTotalLimit Commit Total Limit
   */
  function setCommitLimit(uint256 _commitUserLimit, uint256 _commitTotalLimit) external onlyOwner {
    require(_commitUserLimit != 0, "INVALID_USER_LIMIT");
    require(_commitTotalLimit != 0, "INVALID_TOTAL_LIMIT");
    require(_commitUserLimit <= _commitTotalLimit, "USER_LIMIT_SHOULD_BE_LESS_THAN_TOTAL_LIMIT");
    COMMIT_USER_LIMIT = _commitUserLimit;
    COMMIT_TOTAL_LIMIT = _commitTotalLimit;
    emit CommitLimitConfigured(_commitUserLimit, _commitTotalLimit);
  }

  /**
   * @notice Set Allowlist Signer
   * @param _signer Allowlist Signer Address
   */
  function setAllowlistSigner(address _signer) external onlyOwner {
    require(_signer != address(0), "INVALID_ADDRESS");
    ALLOWLIST_SIGNER = _signer;
    emit AllowlistSignerConfigured(_signer);
  }

  /**
   * @notice change Allowlist Check
   * @param _allowlistCheck Allowlist check is true or not
   */
  function changeAllowlistCheck(bool _allowlistCheck) external onlyOwner {
    ALLOWLIST_CHECK = _allowlistCheck;
    emit AllowlistCheckConfigured(_allowlistCheck);
  }

  /**
   * @notice Init Batch Auction
   * @param _commitCurrency Commit Currency
   * @param _auctionToken Auction Token
   * @param _auctionTokenVault Auction Token Vault
   * @param _startTime Start Time of the auction
   * @param _endTime End Time of the auction
   * @param _vestingPeriod Vesting Period
   * @param _claimablePeriod Claimable Period
   * @param _totalOfferingTokens Total Offering Tokens
   * @param _minimumCommitmentAmount Minimum Commitment Amount
   * @param _treasury Treasury Address
   * @param _wallet Auction Wallet Address
   */
  function initAuction(
    address _commitCurrency,
    IERC20 _auctionToken,
    address _auctionTokenVault,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _vestingPeriod,
    uint256 _claimablePeriod,
    uint256 _totalOfferingTokens,
    uint256 _minimumCommitmentAmount,
    address _treasury,
    address payable _wallet
  ) external onlyOwner {
    require(_startTime > block.timestamp, "INVALID_AUCTION_START_TIME");
    require(_startTime < _endTime, "INVALID_AUCTION_END_TIME");
    require(_vestingPeriod > 0, "INVALID_VESTING_PERIOD");
    require(_claimablePeriod > 0, "INVALID_CLAIMABLE_PERIOD");
    require(_vestingPeriod < _claimablePeriod, "INVALID_PERIOD");
    require(_totalOfferingTokens > 0,"INVALID_TOTAL_OFFERING_TOKENS");
    require(_minimumCommitmentAmount > 0,"INVALID_MINIMUM_COMMITMENT_AMOUNT");
    require(_auctionTokenVault != address(0), "INVALID_AUCTION_TOKEN_VAULT");
    require(_treasury != address(0), "INVALID_TREASURY_ADDRESS");
    require(_wallet != address(0), "INVALID_AUCTION_WALLET_ADDRESS");

    COMMIT_CURRENCY = _commitCurrency;
    AUCTION_TOKEN = _auctionToken;
    AUCTION_TOKEN_VAULT = _auctionTokenVault;
    AUCTION_TREASURY = _treasury;
    AUCTION_WALLET = _wallet;
    VESTING_PERIOD = _vestingPeriod;
    CLAIMABLE_PERIOD = _claimablePeriod;

    auctionData.startTime = _startTime;
    auctionData.endTime = _endTime;
    auctionData.totalOfferingTokens = _totalOfferingTokens;
    auctionData.minCommitmentsAmount = _minimumCommitmentAmount;
    auctionData.finalized = false;
    auctionData.totalLPTokenAmount = 0;

    numOfParticipants = 0;

    if (COMMIT_CURRENCY == ETH_ADDRESS) {
      /// Commit Currency is ETH (BNB in BSC Network)
      WITHDRAW_CAP_MIN = 5e18; // 5 BNB
      WITHDRAW_CAP_MAX = 250e18; // 250 BNB
      WITHDRAW_CAP_LIMIT = 75e18; // 75 BNB
      WITHDRAW_CAP_INTERCEPT = 2; 
      WITHDRAW_CAP_INTERCEPT_PLUS = 25e18; // 25 BNB
      WITHDRAW_CAP_INTERCEPT_DIV = 7;
    } else {
      /// Commit Currency is ERC20 (BEP20 in BSC Network)
      WITHDRAW_CAP_MIN = 2000e18; //  2,000 USDT
      WITHDRAW_CAP_MAX = 100000e18; // 100,000 USDT
      WITHDRAW_CAP_LIMIT = 30000e18; //  30,000 USDT
      WITHDRAW_CAP_INTERCEPT = 2;
      WITHDRAW_CAP_INTERCEPT_PLUS = 10000e18; // 10,000 USDT
      WITHDRAW_CAP_INTERCEPT_DIV = 7;
    }

    emit AuctionInitialized(
      _commitCurrency,
      _auctionToken,
      _auctionTokenVault,
      _startTime,
      _endTime,
      _totalOfferingTokens,
      _minimumCommitmentAmount,
      _treasury,
      _wallet
    );
  }

  /**
   * @notice Transfer Auction Token to this contract
   * @dev Only Owner can call this function
   */
  function transferAuctionTokenFromVault() external onlyOwner nonReentrant {
    require(getAuctionTokenBalance() == 0, 'AUCTION_TOKEN_BALANCE_SHOULD_BE_ZERO');

    uint256 amount = auctionData.totalOfferingTokens;
    require(amount > 0, 'INVALID_TOTAL_OFFERING_TOKENS');

    IERC20(AUCTION_TOKEN).safeTransferFrom(AUCTION_TOKEN_VAULT, address(this), amount);

    emit AuctionTokenTransferredFromVault(AUCTION_TOKEN_VAULT, amount);
  }

  /**
   * @notice Cancel Auction Before Start
   * @dev Only Owner can cancel the auction before it starts
   */
  function cancelAuctionBeforeStart() external onlyOwner {
    require(!auctionData.finalized, "AUCTION_SHOULD_NOT_BE_FINALIZED"); 
    require(auctionData.totalCommitments == 0, "AUCTION_HAS_COMMITMENTS");

    IERC20(AUCTION_TOKEN).safeTransfer(AUCTION_TOKEN_VAULT, auctionData.totalOfferingTokens);

    auctionData.finalized = true;

    emit AuctionCancelled();
  }

  /**
   * @notice Commit ETH with signature
   * @param _signature Signature of the user
   */
  function commitETH(bytes calldata _signature) external payable isAuctionWindow {
    require(COMMIT_CURRENCY == ETH_ADDRESS, "INVALID_COMMIT_CURRENCY");

    uint256 actualCommitAmount = _addCommitment(msg.sender, msg.value, _signature);
    uint256 ethToRefund = msg.value - actualCommitAmount;

    /// @dev Return any ETH to be refunded.
    if (ethToRefund > 0) {
      _safeTransferETH(payable(msg.sender), ethToRefund);
    }

    /// @dev Revert if totalCommitments exceeds the balance
    require(auctionData.totalCommitments <= address(this).balance, "INVALID_TOTAL_COMMITMENTS");

    emit ETHCommitted(msg.sender, actualCommitAmount);
  }

  /**
   * @notice Commit ERC20 Token with signature
   * @param _signature Signature of the user
   */
  function commitERC20Token(uint256 _amount, bytes calldata _signature) external isAuctionWindow {
    require(COMMIT_CURRENCY != ETH_ADDRESS, "INVALID_COMMIT_CURRENCY");

    uint256 actualCommitAmount = _addCommitment(msg.sender, _amount, _signature);

    IERC20(COMMIT_CURRENCY).safeTransferFrom(msg.sender, address(this), actualCommitAmount);

    emit TokenCommitted(msg.sender, actualCommitAmount);
  }
    
  /**
   * @notice Withdraw ETH during the auction
   * @param _amount Withdraw Amount
   */
  function withdrawETH(uint256 _amount) external isAuctionWindow nonReentrant {
    require(COMMIT_CURRENCY == ETH_ADDRESS, "INVALID_COMMIT_CURRENCY");

    _withdrawCommitment(msg.sender, _amount);

    _safeTransferETH(payable(msg.sender), _amount);

    emit ETHWithdrawn(msg.sender, _amount);
  }

  /**
   * @notice Withdraw ERC20 token during the auction
   * @param _amount Withdraw Amount
   */
  function withdrawERC20Token(uint256 _amount) external isAuctionWindow nonReentrant {
    require(COMMIT_CURRENCY != ETH_ADDRESS, "INVALID_COMMIT_CURRENCY");

    _withdrawCommitment(msg.sender, _amount);

    IERC20(COMMIT_CURRENCY).safeTransfer(msg.sender, _amount);

    emit ERC20TokenWithdrawan(msg.sender, _amount);
  }
  
  /**
   * @notice Claim Instant Token
   * @dev The Auction should be finalized with success and valid claimable period
   */
  function claimInstantToken() external isAuctionFinalizedWithSuccess isClaimablePeriod {
    require(!USER_RECEIVED_INSTANT_TOKEN[msg.sender], "USER_ALREADY_CLAIMED_INSTANT_TOKEN");

    uint256 amount = getInstantTokenAmount(msg.sender);
    require(amount > 0, "NOT_ENOUGH_TOKEN_TO_CLAIM");

    USER_RECEIVED_INSTANT_TOKEN[msg.sender] = true;
    IERC20(AUCTION_TOKEN).safeTransfer(msg.sender, amount);

    emit InstantTokenClaimed(msg.sender, amount, COMMITMENTS[msg.sender]);
  }

  /**
   * @notice Claim Vested LP Token
   * @dev The Auction should be finalized with success and can claim vested lp token
   */
  function claimVestedLPToken() external isAuctionFinalizedWithSuccess canClaimVestedLPToken(msg.sender) {
    uint256 amount = getActualVestedLPTokenAmount(msg.sender);
    require(amount > 0, "NOT_ENOUGH_VESTED_LPTOKEN_TO_CLAIM");

    VESTED_LPTOKEN_CLAIMED[msg.sender] += amount;
    IPancakePair(PANCAKE_LPTOKEN).transfer(msg.sender, amount);

    emit VestedLPTokenClaimed(msg.sender, amount);
  }

  /**
   * @notice withdraw unclaimed Auction token, transferring to Treasury.
   * @dev only operator can execute
   */
  function withdrawUnclaimedAuctionToken() external isClaimablePeriodEnded onlyOwner {
    uint256 amount = getAuctionTokenBalance();
    require(amount > 0, "INVALID_AMOUNT");

    IERC20(AUCTION_TOKEN).safeTransfer(AUCTION_TREASURY, amount);

    emit UnclaimedTokenWithdrawan(AUCTION_TREASURY, amount);
  }

  /**
   * @notice withdraw unclaimed LP token, transferring to Treasury.
   * @dev only operator can execute
   */
  function withdrawUnclaimedLPToken() external isClaimablePeriodEnded onlyOwner {
    uint256 amount = getLPTokenBalance();
    require(amount > 0, "INVALID_AMOUNT");

    IPancakePair(PANCAKE_LPTOKEN).transfer(AUCTION_TREASURY, amount);

    emit UnclaimedLPTokenWithdrawn(AUCTION_TREASURY, amount);
  }

  /**
   * @notice claim commitment when project failed (after auction finished and finalized)
   */
  function getCommitmentBack() external canCommitmentBack nonReentrant {
    uint256 userCommitted = COMMITMENTS[msg.sender];
    require(userCommitted > 0, "NO_COMMITMENTS");

    COMMITMENTS[msg.sender] = 0; 

    if(COMMIT_CURRENCY == ETH_ADDRESS) {
      _safeTransferETH(payable(msg.sender), userCommitted);
    } else {
      IERC20(COMMIT_CURRENCY).safeTransfer(msg.sender, userCommitted);
    }

    emit GotCommitmentBack(msg.sender, userCommitted);
  }

  /**
   * @notice Finalize Auction with Success
   * @dev The auction was successful, transfer contributed tokens to the auction wallet. Only operator can execute.
   * @param _lpTokenAddress LP Token Address
   * @param _minLP minimum LP value expected to be minted
   */
  function finalizeAuctionWithSuccess(address _lpTokenAddress, uint256 _minLP) external canFinalizeAuction onlyOwner {
    require(_lpTokenAddress != address(0), "INVALID_LP_TOKEN_ADDRESS");
    require(isAuctionSuccessful(), "AUCTION_SHOULD_BE_SUCCESSFUL");

    /// 70% of funds goes to the AUCTION_WALLET
    uint256 transferAmount = (auctionData.totalCommitments * 7) / 10; // 70%

    if(COMMIT_CURRENCY == ETH_ADDRESS) {
      _safeTransferETH(AUCTION_WALLET, transferAmount);
    } else {
      IERC20(COMMIT_CURRENCY).safeTransfer(AUCTION_WALLET, transferAmount);
    }

    /// 30% of funds & 30% of AUCTION_TOKEN instantly goes to DEX POOL
    uint256 token1Amount = (auctionData.totalOfferingTokens * 3) / 10; // 30%
    uint256 token2Amount = (auctionData.totalCommitments * 3) / 10; // 30%

    PANCAKE_LPTOKEN = _lpTokenAddress;

    auctionData.totalLPTokenAmount = _setupPancakeSwapPool(
      _lpTokenAddress, address(AUCTION_TOKEN), COMMIT_CURRENCY,
      token1Amount, token2Amount, _minLP
    );

    require(auctionData.totalLPTokenAmount > 0, "INVALID_LPTOKEN_AMOUNT");

    emit FinalizedAuctionWithSuccess(
      transferAmount,
      token1Amount,
      token2Amount,
      _lpTokenAddress,
      auctionData.totalLPTokenAmount
    );
    
    auctionData.finalized = true;
  }

  /**
   * @notice Finalize Auction With Failure
   * @dev only operator can execute
   */
  function finalizeAuctionWithFailure() external canFinalizeAuction onlyOwner {
    require(!isAuctionSuccessful(), "AUCTION_SHOULD_NOT_BE_SUCCESSFUL");

    // If the auction was not successful, return auction tokens to the AUCTION_TOKEN_VAULT
    IERC20(AUCTION_TOKEN).safeTransfer(AUCTION_TOKEN_VAULT, auctionData.totalOfferingTokens);
    emit FinalizedAuctionWithFailure(auctionData.totalOfferingTokens);
    
    auctionData.finalized = true;
  }
  
  /* ========== PUBLIC VIEWS ========== */
  /**
   * @notice Is User in the allowlist
   * @param _user Address of the user
   * @param _signature Signature of the user
   * @return True if the user is in the allowlist
   */
  function isAllowlist(address _user, bytes calldata _signature) public view returns (bool) {
    return _verifySignature(_user, _signature, "ALLOWLIST");
  }

  /**
   * @notice Get Auction Token Balance
   * @return Auction token balance
   */
  function getAuctionTokenBalance() public view returns (uint256) {
    require(address(AUCTION_TOKEN) != address(0), "INVALID_AUCTION_TOKEN");
    return IERC20(AUCTION_TOKEN).balanceOf(address(this));
  }

  /**
   * @notice Get LP Token Balance
   * @return LP Token Balance
   */
  function getLPTokenBalance() public view returns (uint256) {
    require(PANCAKE_LPTOKEN != address(0), "INVALID_PANCAKE_LPTOKEN");
    return IPancakePair(PANCAKE_LPTOKEN).balanceOf(address(this));
  }

  /**
   * @notice Get estimated amount of instant tokens
   * @dev user can claim 70% of tokens instantly without vesting
   * @param _user Address of the user
   * @return Instant token amount
   */
  function getInstantTokenAmount(address _user) public view returns (uint256) {
    require(COMMITMENTS[_user] > 0, "NO_COMMITMENTS");
    uint256 userShare = (COMMITMENTS[_user] * 7) / 10; // 70%
    return (auctionData.totalOfferingTokens * userShare) / auctionData.totalCommitments;
  }

  /**
   * @notice Get actual vested lp token amount
   * @param _user Address of the user
   * @return Total vested LP Token amount
   */
  function getActualVestedLPTokenAmount(address _user)
    public view isAuctionFinalizedWithSuccess canClaimVestedLPToken(_user) returns (uint256) {
    return getTotalVestedLPTokenAmount(_user) - VESTED_LPTOKEN_CLAIMED[_user];
  }

  /**
   * @notice dev Get total vested lp token Amount with Vesting
   * @param _user Address of the user
   * @return Vested LP Token amount
   */
  function getTotalVestedLPTokenAmount(address _user) 
    public view isAuctionFinalizedWithSuccess canClaimVestedLPToken(_user) returns (uint256) {
    uint256 vestingTimeElapsed = block.timestamp - auctionData.endTime;
    if (vestingTimeElapsed > VESTING_PERIOD) {
      vestingTimeElapsed = VESTING_PERIOD;
    }

    return (getAllocatedLPTokenAmount(_user) * vestingTimeElapsed) / VESTING_PERIOD;
  }
  
  /**
   * @notice Get Allocated LP token amount for the user
   * @param _user Address of the user
   * @return Allocated LP Token amount
   */
  function getAllocatedLPTokenAmount(address _user)
    public view isAuctionFinalizedWithSuccess canClaimVestedLPToken(_user) returns (uint256) {
    return (auctionData.totalLPTokenAmount * COMMITMENTS[_user]) / auctionData.totalCommitments;
  }

  /**
   * @notice Checks if the auction was successful
   * @return True if tokens sold greater than or equals to the minimum commitment amount
   */
  function isAuctionSuccessful() public view returns (bool) {
    return auctionData.totalCommitments > 0 
      && (auctionData.totalCommitments >= auctionData.minCommitmentsAmount); 
  }

  /* ========== EXTERNAL VIEWS ========== */
  /**
   * @notice Get Auction Data
   */
  function getAuctionData() external view returns (AuctionData memory) {
    return auctionData;
  }

  /**
   * @notice Get the price of Token
   * @return Token price
   */
  function getTokenPrice() external view returns (uint256) {
    if (auctionData.totalCommitments > 0) {
      return (auctionData.totalCommitments * 1e18) / auctionData.totalOfferingTokens;
    } else {
      return 0;
    }
  }

  /**
   * @notice Calculate the amount of Committed Token that can be withdrawn by user
   * @param _user Address of the user
   * @return withdrawable amount per user
   */
  function getWithdrawableAmount(address _user) external view returns (uint256) {
    return _withdrawableAmountPerUser(_user);
  }

  /**
   * @notice Get Committed amount of the user
   * @param _user Address of the user
   * @return Committed amount of the user
   */
  function getCommittedAmount(address _user) external view returns (uint256) {
    return COMMITMENTS[_user];
  }

  /**
   * @notice Get Total Locked amount of the user
   * @param _user Address of the user
   * @return Locked Amount of the user
   */
  function getLockedAmount(address _user) external view returns (uint256) {
    return COMMITMENTS[_user] - _withdrawableAmountPerUser(_user);
  }

  /**
   * @notice Calculate withdrawable amount after deposit
   * @param _user Address of the user
   * @param _deposit Deposit Amount
   * @return Withdrawable amount after deposit
   */
  function getWithdrawableAmountAfterDeposit(address _user, uint256 _deposit) external view returns (uint256) {
    return _withdrawableAmountAfterDeposit(_user, _deposit);
  }

  /**
   * @notice Calculate locked amount after deposit
   * @param _user Address of the user
   * @param _deposit Deposit Amount
   * @return Locked amount after deposit
   */
  function getLockedAmountAfterDeposit(address _user, uint256 _deposit) external view returns (uint256) {
    return (COMMITMENTS[_user] + _deposit) - _withdrawableAmountAfterDeposit(_user, _deposit);
  }

  /**
   * @notice Check if the user already received or not
   * @param _user Address of the user
   * @return True if user received instant token
   */
  function isUserReceivedInstantToken(address _user) external view returns (bool) {
    return USER_RECEIVED_INSTANT_TOKEN[_user];
  }

  /* ========== INTERNAL FUNCTIONS ========== */
  /**
   * @notice Safe Transfer ETH
   */
  function _safeTransferETH(address payable to, uint value) internal {
    (bool success,) = to.call{value:value}(new bytes(0));
    require(success, 'ETH_TRANSFER_FAILED');
  }

  /**
   * @notice Add Commitment
   * @param _user Address of the user
   * @param _amount Amount to add
   * @param _signature allowlist signature
   */
  function _addCommitment(address _user, uint256 _amount, bytes calldata _signature)
    internal isAuctionWindow returns (uint256) {
    require(_amount > 0, "INVALID_AMOUNT");
    require(COMMITMENTS[_user] < COMMIT_USER_LIMIT, "EXCEED_COMMIT_USER_LIMIT");
    require(auctionData.totalCommitments < COMMIT_TOTAL_LIMIT, "EXCEED_COMMIT_TOTAL_LIMIT");

    /// @dev verify allowlist only if ALLOWLIST_CHECK is true
    if(ALLOWLIST_CHECK) {
      require(isAllowlist(msg.sender, _signature), "USER_NOT_IN_ALLOWLIST");
    }

    /// @dev Calculate over commit total amount
    uint256 overCommitTotalAmount = 0;
    if((auctionData.totalCommitments + _amount) > COMMIT_TOTAL_LIMIT) {
      overCommitTotalAmount = (auctionData.totalCommitments + _amount) - COMMIT_TOTAL_LIMIT;
    }

    /// @dev Calculate over commit user amount
    uint256 overCommitUserAmount = 0;
    if((COMMITMENTS[_user] + _amount) > COMMIT_USER_LIMIT) {
      overCommitUserAmount = (COMMITMENTS[_user] + _amount) - COMMIT_USER_LIMIT;
    }

    /// @dev Calculate actual commit amount
    uint256 actualCommitAmount = _amount;
    if(overCommitUserAmount > overCommitTotalAmount) {
      actualCommitAmount -= overCommitUserAmount;
    } else {
      actualCommitAmount -= overCommitTotalAmount;
    }

    COMMITMENTS[_user] += actualCommitAmount;
    ACCUMULATED_COMMITMENTS[_user] += actualCommitAmount;
    auctionData.totalCommitments += actualCommitAmount;

    if (!PARTICIPATED[_user]) {
      numOfParticipants += 1;
      PARTICIPATED[_user] = true;
    }

    emit CommitmentAdded(_user, _amount);

    return actualCommitAmount;
  }

  /**
   * @notice Withdraw Commitment
   * @param _user Address of the user
   * @param _amount Amount to withdraw
   */
  function _withdrawCommitment(address _user, uint256 _amount) internal isAuctionWindow {
    require(_amount > 0, "INVALID_AMOUNT");
    require(_amount <= COMMITMENTS[_user], "INSUFFICIENT_COMMITMENTS_BALANCE");
    require(_amount <= _withdrawableAmountPerUser(_user), "INVALID_WITHDRAW_AMOUNT");

    COMMITMENTS[_user] -= _amount;
    ACCUMULATED_WITHDRAWALS[_user] += _amount;
    auctionData.totalCommitments -= _amount;

    emit CommitmentWithdrawn(_user, _amount);
  }

  /**
   * @notice Withdrawable Amount After Deposit
   * @param _user Address of the user
   * @param _amount Amount to withdraw
   * @return Withdrawable Amount after deposit
   */
  function _withdrawableAmountAfterDeposit(address _user, uint256 _amount) internal view returns (uint256)  {
    require(_amount > 0, "INVALID_AMOUNT");
    return _withdrawableAmountPerCommitments(ACCUMULATED_COMMITMENTS[_user] + _amount) - ACCUMULATED_WITHDRAWALS[_user];
  }
 
  /**
   * @notice Calculate Withdrawable Amount based on user
   * @param _user Address of the user
   * @return Withdrawable Amount per user
   */
  function _withdrawableAmountPerUser(address _user) internal view returns (uint256) {
    require(COMMIT_CURRENCY != address(0), "INVALID_COMMIT_CURRENCY");
    return _withdrawableAmountPerCommitments(ACCUMULATED_COMMITMENTS[_user]) - ACCUMULATED_WITHDRAWALS[_user];
  }

  /**
   * @notice Calculate Withdrawable Amount based on Commitments
   * @param _amount Commitment
   * @return withdraw cap
   */
  function _withdrawableAmountPerCommitments(uint256 _amount) internal view returns (uint256) {
    if (_amount <= WITHDRAW_CAP_MIN) {
      return _amount;
    } else if (_amount < WITHDRAW_CAP_MAX) {
      return ((_amount * WITHDRAW_CAP_INTERCEPT) + WITHDRAW_CAP_INTERCEPT_PLUS) / WITHDRAW_CAP_INTERCEPT_DIV;
    } else { 
      return WITHDRAW_CAP_LIMIT;
    }
  }

  /**
   * @notice Setup Pancake Swap Pool
   * @param _lpTokenAddress Pancake Swap LP Address
   * @param _token1 First Token
   * @param _token2 Second Token
   * @param _token1Amount First Token Amount
   * @param _token2Amount Second Token Amount
   * @param _minLP minimum LP value expected to be minted
   * @return LP Token Amount
   */
  function _setupPancakeSwapPool(
    address _lpTokenAddress,
    address _token1,
    address _token2,
    uint256 _token1Amount,
    uint256 _token2Amount,
    uint256 _minLP
  ) internal onlyOwner returns (uint256) {
    require(_lpTokenAddress != address(0), "INVALID_LP_ADDRESS");
    require(_token1Amount > 0, "INVALID_TOKEN1_AMOUNT");
    require(_token2Amount > 0, "INVALID_TOKEN2_AMOUNT");
    require(auctionData.endTime < block.timestamp, "AUCTION_NOT_ENDED");
    require(isAuctionSuccessful(), "AUCTION_SHOULD_BE_SUCCESSFUL");

    uint256 lpTokenAmount = 0;

    if(_token2 == ETH_ADDRESS) {
      _token2 = WETH_ADDRESS; // token2 should be WETH_ADDRESS (WETH is WBNB in BSC)
    }

    IERC20(_token1).safeTransfer(_lpTokenAddress, _token1Amount);

    if(_token2 == WETH_ADDRESS) {
      // If second token is WETH_ADDRESS
      IWETH(_token2).deposit{value: _token2Amount}();
      assert(IWETH(_token2).transfer(_lpTokenAddress, _token2Amount));
    } else {
      // If the second token is ERC20 (BEP20 in BSC Network)
      IERC20(_token2).safeTransfer(_lpTokenAddress, _token2Amount);
    }

    ///@dev mint LP token
    lpTokenAmount = IPancakePair(_lpTokenAddress).mint(address(this));
    require(_minLP <= lpTokenAmount, "LOWER_THAN_EXPECTED_LP_AMOUNT");

    emit PancakeSwapPoolCreated(_lpTokenAddress, _token1Amount, _token2Amount, lpTokenAmount);

    return lpTokenAmount;
  }

  /**
   * @notice Check Valid Claimable Period
   * @return True if valid
   */
  function _isValidClaimablePeriod() internal view returns (bool) {
    return (block.timestamp > auctionData.endTime
         && block.timestamp < (auctionData.endTime + CLAIMABLE_PERIOD));
  }

  /**
   * @notice Verify Signature
   * @param _user Address of the user
   * @param _signature Signature of the user
   * @param _state Allowlist string
   * @return True if verified
   */
  function _verifySignature(address _user, bytes memory _signature, string memory _state)
    internal view returns (bool) {
    return ALLOWLIST_SIGNER == keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",
        bytes32(abi.encodePacked(_user, _state, DOMAIN_SEPARATOR)))
      ).recover(_signature);
  }
}