// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

// =====================================================================
//
// |  \/  (_) |         | |                 |  _ \                   | |
// | \  / |_| | ___  ___| |_ ___  _ __   ___| |_) | __ _ ___  ___  __| |
// | |\/| | | |/ _ \/ __| __/ _ \| '_ \ / _ \  _ < / _` / __|/ _ \/ _` |
// | |  | | | |  __/\__ \ || (_) | | | |  __/ |_) | (_| \__ \  __/ (_| |
// |_|  |_|_|_|\___||___/\__\___/|_| |_|\___|____/ \__,_|___/\___|\__,_|
//
// =====================================================================
// ======================= ContractsRegistry ===========================
// =====================================================================

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IContractsRegistry.sol";

/**
 * @title ContractsRegistry
 * @author milestoneBased R&D Team
 *
 * @dev Implementation of the {IContractsRegistry} interface.
 *
 * This contract implements a registry of contracts by {uint256} key. Provides
 * opportunities for contract registration, collection by key, as well as
 * deletion from the register
 *
 * The contract inherits {OwnableUpgradeable} from the OpenZeppelin contracts
 * as it is also upgradeable for future expansion
 *
 * WARNING: The `Owner` of the contract has very important rights to change
 * contracts in the system, be as careful as possible with him,
 * we recommend using `MultiSign` for owner address
 */
contract ContractsRegistry is IContractsRegistry, OwnableUpgradeable {
  /**
   * @dev Mapping for storing contract addresses by keys
   */
  mapping(uint256 => address) public override register;

  /**
   * @dev Function to initialize the contract which replaces the constructor.
   * Appointment to establish the owner of the contract. Can be called only once
   */
  function initialize() external virtual override initializer {
    __Ownable_init();
  }

  /**
   * @dev Registers `contractAddress_` by `key_`.
   *
   * If `key_` had been registered, then the function will update
   * the address by key to a new one
   *
   * Requirements:
   *
   * - the caller must be `Owner`.
   * - `contractAddress_` must be not `ZERO_ADDRESS`
   *
   * Emits a {UpdateKey} event.
   */
  function registerContract(uint256 key_, address contractAddress_)
    external
    virtual
    override
    onlyOwner
  {
    _registerContract(key_, contractAddress_);
    emit UpdateKey(key_, contractAddress_);
  }

  /**
   * @dev Registers `contractsAddresses_` by `keys_`.
   *
   * If any key from `keys_` had been registered, then the function will update
   * the address by key to a new one
   *
   * Keys are tied to addresses, and addresses are tied to keys by the number
   * of the element in the arrays
   *
   * Requirements:
   *
   * - the caller must be `Owner`.
   * - `contractsAddresses_` must be not containts `ZERO_ADDRESS`
   * - arrays must be of the same length
   *
   * Emits a {UpdateKeys} event.
   */
  function registerContracts(
    uint256[] calldata keys_,
    address[] calldata contractsAddresses_
  ) external virtual override onlyOwner {
    if (keys_.length != contractsAddresses_.length) {
      revert ArrayDifferentLength();
    }

    unchecked {
      for (uint256 i; i < keys_.length; ++i) {
        _registerContract(keys_[i], contractsAddresses_[i]);
      }
    }

    emit UpdateKeys(keys_, contractsAddresses_);
  }

  /**
   * @dev Unregisters `contractAddress_` by `key_`.
   *
   * If `key_` had not been registered, then the function will revert
   *
   * Requirements:
   *
   * - the caller must be `Owner`.
   * - `key_` must be registered
   *
   * Emits a {UpdateKey} event.
   */
  function unregisterContract(uint256 key_)
    external
    virtual
    override
    onlyOwner
  {
    address contractAddress = register[key_];
    if (contractAddress == address(0)) {
      revert KeyNotRegistered(key_);
    }
    delete register[key_];
    emit UpdateKey(key_, address(0));
  }

  /**
   * @dev Returns the status of whether the `key_` is registered
   *
   * Returns types:
   * - `false` - if contract not registered
   * - `true` - if contract registered
   */
  function isRegistered(uint256 key_)
    external
    view
    virtual
    override
    returns (bool result)
  {
    result = register[key_] != address(0);
  }

  /**
   * @dev Returns the contract address by `key_`
   *
   * IMPORTANT: If `key_` had not been registered, then the function will revert
   */
  function getContractByKey(uint256 key_)
    external
    view
    virtual
    override
    returns (address result)
  {
    result = register[key_];

    if (result == address(0)) {
      revert KeyNotRegistered(key_);
    }
  }

  /**
   * @dev Returns the contracts addresses by `keys_`
   *
   * Keys are tied to addresses, and addresses are tied to keys by the number
   * of the element in the arrays
   *
   * IMPORTANT: If any key from `keys_` had not been registered, then the function will revert
   */
  function getContractsByKeys(uint256[] calldata keys_)
    external
    view
    virtual
    override
    returns (address[] memory result)
  {
    result = new address[](keys_.length);

    unchecked {
      for (uint256 i; i < keys_.length; ++i) {
        address registeredAddress = register[keys_[i]];
        if (registeredAddress == address(0)) {
          revert KeyNotRegistered(keys_[i]);
        }
        result[i] = registeredAddress;
      }
    }
  }

  /**
   * @dev Internal registration mechanism
   */
  function _registerContract(uint256 key_, address contractAddress_)
    internal
    virtual
  {
    if (contractAddress_ == address(0)) {
      revert ZeroAddress();
    }

    register[key_] = contractAddress_;
  }
}