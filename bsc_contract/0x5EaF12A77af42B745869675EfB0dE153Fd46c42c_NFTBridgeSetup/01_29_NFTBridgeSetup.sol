// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./NFTBridgeGovernance.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

contract NFTBridgeSetup is NFTBridgeSetters, ERC1967Upgrade {
    function setup(
        address implementation,
        uint16 chainId,
        address zkBridge,
        address tokenImplementation,
        address owner,
        uint256 lockTime
    ) public {
        _setOwner(owner);

        _setChainId(chainId);

        _setZKBridge(zkBridge);

        _setLockTime(lockTime);

        _setTokenImplementation(tokenImplementation);

        _upgradeTo(implementation);
    }
}