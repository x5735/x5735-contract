// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {StableMath} from "../utils/StableMath.sol";
import {Governable} from "../governance/Governable.sol";
import {Initializable} from "../utils/Initializable.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IUniswapV2Pair} from "../interfaces/uniswap/IUniswapV2Pair.sol";
import "hardhat/console.sol";

contract RebaseToNonEoaHandler is Initializable, Governable {
  using SafeERC20 for IERC20;
  using StableMath for uint256;

  IVault public vault;
  IERC20 public primaryToken;
  IERC20 public lfMatic;

  struct Contract {
    address contractAddress;
    bytes32 poolId;
    bool isSatin;
    bool isSupported;
  }
  mapping(address => Contract) public contracts;
  address[] public allContracts;
  uint256 public contractsCount;
  uint256 public partnerBps;
  address public multiRewardPool;

  event ContractRemoved(address _contract);
  event PartnerRemitted(address _partner, uint256 _amount);
  event RewardPoolRemitted(address _mrp, uint256 _amount);

  /**
   * @dev Verifies that the caller is the Vault or Governor.
   */
  modifier onlyVaultOrGovernor() {
    require(msg.sender == address(vault) || msg.sender == governor(), "Caller is not the Vault or Governor");
    _;
  }

  function initialize(
    address _vaultAddress,
    address _primaryTokenAddress,
    address _lfMatic
  ) external onlyGovernor initializer {
    require(address(_vaultAddress) != address(0), "Vault Missing");
    require(address(_primaryTokenAddress) != address(0), "PS Missing");
    vault = IVault(_vaultAddress);
    primaryToken = IERC20(_primaryTokenAddress);
    lfMatic = IERC20(_lfMatic);
    partnerBps = 2000; // Default 20%
  }

  function addContract(address _contractAddress, bytes32 _poolId, bool _isSatin) external onlyGovernor {
    require(address(_contractAddress) != address(0), "Contract Missing");
    require(_poolId != bytes32(0), "PoolId Missing");
    contracts[_contractAddress] = Contract(_contractAddress, _poolId, _isSatin, true);
    allContracts.push(_contractAddress);
    contractsCount++;
  }

  function removeContract(address _contractAddress) external onlyGovernor {
    require(address(_contractAddress) != address(0), "Contract Missing");
    uint256 index = allContracts.length;
    for (uint256 i = 0; i < allContracts.length; i++) {
      if (allContracts[i] == _contractAddress) {
        index = i;
        break;
      }
    }
    if (index < allContracts.length) {
      allContracts[index] = allContracts[allContracts.length - 1];
      allContracts.pop();
      emit ContractRemoved(_contractAddress);
    }
    contracts[_contractAddress].isSupported = false;
    contractsCount--;
  }

  function setPartnerBps(uint256 _partnerBps) external onlyGovernor {
    require(_partnerBps > 0 && partnerBps <= 5000); // Should not be more than 50%
    partnerBps = _partnerBps;
  }

  function setMultiRewardPool(address _multiRewardPool) external onlyGovernor {
    multiRewardPool = _multiRewardPool;
  }

  function process() external onlyVaultOrGovernor {
    for (uint256 i = 0; i < allContracts.length; i++) {
      address contractAddress = allContracts[i];
      Contract memory contractInfo = contracts[contractAddress];
      if (contractInfo.isSupported && contractInfo.isSatin) {
        IUniswapV2Pair uniswapPair = IUniswapV2Pair(contractAddress);
        address token0 = uniswapPair.token0();
        address token1 = uniswapPair.token1();
        uint256 skimmableLfMaticAmount = 0;
        address skimmableToken;
        uint256 skimmableTokenAmount = 0;
        (uint256 reserve0, uint256 reserve1, ) = uniswapPair.getReserves();
        if (address(token0) == address(lfMatic)) {
          skimmableLfMaticAmount = lfMatic.balanceOf(contractAddress) - reserve0;
          skimmableToken = token1;
          skimmableTokenAmount = IERC20(token1).balanceOf(contractAddress) - reserve1;
        } else if (address(token1) == address(lfMatic)) {
          skimmableToken = token0;
          skimmableTokenAmount = IERC20(token0).balanceOf(contractAddress) - reserve0;
          skimmableLfMaticAmount = lfMatic.balanceOf(contractAddress) - reserve1;
        }
        if (skimmableLfMaticAmount > 0) {
          IUniswapV2Pair(contractAddress).skim(address(this));
          try uniswapPair.partnerAddress() returns (address partnerAddress) {
            if (partnerAddress != address(0)) {
              uint256 _pAmount = (skimmableLfMaticAmount * partnerBps) / 10_000;
              lfMatic.transfer(partnerAddress, _pAmount);
              emit PartnerRemitted(partnerAddress, _pAmount);
              skimmableLfMaticAmount -= _pAmount;
            }
          } catch {}
          // Rest has to be sent to the SMRP
          lfMatic.transfer(multiRewardPool, skimmableLfMaticAmount);
          emit RewardPoolRemitted(multiRewardPool, skimmableLfMaticAmount);
        } else {}

        // Send other token (if any) to the governor
        if (skimmableTokenAmount > 0) {
          IERC20(skimmableToken).transfer(governor(), skimmableTokenAmount);
        }
      }
    }
  }
}