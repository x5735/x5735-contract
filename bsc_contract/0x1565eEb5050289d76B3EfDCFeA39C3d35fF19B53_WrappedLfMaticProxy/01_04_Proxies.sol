// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import {InitializeGovernedUpgradeabilityProxy} from "./InitializeGovernedUpgradeabilityProxy.sol";

/**
 * @notice LfMaticProxy delegates calls to an lfMatic implementation
 */
contract LfMaticProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice WrappedLfMaticProxy delegates calls to a WrappedLfMatic implementation
 */
contract WrappedLfMaticProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice VaultProxy delegates calls to a Vault implementation
 */
contract VaultProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice BalancerWMATICSTMATICStrategyProxy delegates calls to a BalancerStrategy implementation
 */
contract BalancerWMATICSTMATICStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice BalancerWMATICMATICXStrategyProxy delegates calls to a BalancerStrategy implementation
 */
contract BalancerWMATICMATICXStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice MeshSwapStrategyProxy delegates calls to a MeshswapStrategy implementation
 */
contract MeshSwapStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice DForceWMATICSingleStrategyProxy delegates calls to a MeshswapStrategy implementation
 */
contract DForceWMATICSingleStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice ThenaLpStrategyProxy delegates calls to a MeshswapStrategy implementation
 */
contract ThenaLPStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice AaveLendingStrategyProxy delegates calls to a MeshswapStrategy implementation
 */
contract AaveLendingStrategyProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice HarvesterProxy delegates calls to a Harvester implementation
 */
contract HarvesterProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice DripperProxy delegates calls to a Dripper implementation
 */
contract DripperProxy is InitializeGovernedUpgradeabilityProxy {

}

/**
 * @notice RebaseToNonEoaHandlerProxy delegates calls to a RebaseToNonEoaHandler implementation
 */
contract RebaseToNonEoaHandlerProxy is InitializeGovernedUpgradeabilityProxy {

}