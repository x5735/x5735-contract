// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// Revision: 2023-2-22
// version 1.0.0

/// OpenZeppelin dependencies
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @dev gasless transaction dependencies
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./DVCCForwarder.sol";

/// @dev dependencies
import "./TransferHelper.sol";

contract DVCCGameService is Pausable, AccessControl, ERC2771Context {
  struct RewardResult {
    uint256 totalReward;
    bool isOpen;
    address[] playerWallets;
    string[] playerIds;
    uint256[] amounts;
  }

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  address _dvcToken;
  bool _defaultGameOnly; // limit only authorized gas relayer

  event GameAction(address playerWallet, string playerId, string orderId, string service, uint256 amount);

  /// @notice Gasless Transaction, use DVCC to pay gasfee
  modifier convertGasfee(string memory action) {
    uint256 totalGas = gasleft();

    if (_defaultGameOnly) {
      require(isTrustedForwarder(msg.sender), "DVCCGameService: only authorized game service can call this function");
    }
    _;

    /// @dev pay gas fee with dvcc
    if (isTrustedForwarder(msg.sender)) {
      TransferHelper.safeGasFeeClaim(_dvcToken, totalGas, _msgSender(), action);
    }
  }

  constructor(DVCCForwarder forwarder) ERC2771Context(address(forwarder)) {
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(MANAGER_ROLE, _msgSender());
    _grantRole(PAUSER_ROLE, _msgSender());
  }

  /// @custom:note - GM functions
  function initializeServices(address dvcToken, bool defaultGameOnly) external onlyRole(MANAGER_ROLE) {
    _dvcToken = dvcToken;
    _defaultGameOnly = defaultGameOnly;
  }

  function gameConsume(
    string memory orderId,
    string memory playerId,
    string memory service,
    uint256 amount
  ) external whenNotPaused convertGasfee("gameConsume") {
    TransferHelper.safeActivityFeeClaim(_dvcToken, amount, _msgSender(), address(this));
    emit GameAction(_msgSender(), playerId, orderId, service, amount);
  }

  function gameDistribute(
    string memory orderId,
    string memory playerId,
    string memory service,
    address playerWallet,
    uint256 amount
  ) external whenNotPaused onlyRole(MANAGER_ROLE) {
    TransferHelper.safeTransfer(address(_dvcToken), playerWallet, amount);
    emit GameAction(playerWallet, playerId, orderId, service, amount);
  }

  function poolInject(uint256 amount) external onlyRole(MANAGER_ROLE) {
    TransferHelper.safeActivityFeeClaim(_dvcToken, amount, _msgSender(), address(this));
  }

  /// @dev Forwarder Override
  function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address sender) {
    if (isTrustedForwarder(msg.sender)) {
      // The assembly code is more direct than the Solidity version using `abi.decode`.
      /// @solidity memory-safe-assembly
      assembly {
        sender := shr(96, calldataload(sub(calldatasize(), 20)))
      }
    } else {
      return super._msgSender();
    }
  }

  function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
    if (isTrustedForwarder(msg.sender)) {
      return msg.data[:msg.data.length - 20];
    } else {
      return super._msgData();
    }
  }
}