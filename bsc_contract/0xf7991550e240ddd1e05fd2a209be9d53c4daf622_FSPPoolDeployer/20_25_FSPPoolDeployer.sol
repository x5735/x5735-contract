// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./FSPPool.sol";

contract FSPPoolDeployer is UUPSUpgradeable, OwnableUpgradeable {
    address public fspFactory;

    modifier onlyFSPFactory() {
        require(fspFactory == msg.sender, "Caller is not fspFactory");
        _;
    }

    event FSPFactoryUpdated(address _factory);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address mfspFactory) external initializer {
        require(mfspFactory != address(0), "Not allowed");
        fspFactory = mfspFactory;
        __Ownable_init();
    }

    function _authorizeUpgrade(address newImplementaion)
        internal
        override
        onlyOwner
    {}

    function createPool(bytes32 salt, address _poolOwner)
        external
        onlyFSPFactory
        returns (address pool)
    {
        bytes memory bytecode = type(FSPPool).creationCode;
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IFSPPool(pool).setFSPFactory(fspFactory);
        IFSPPool(pool).transferOwnership(_poolOwner);
    }

    function setFactoryAddress(address newFactory) external onlyOwner {
        require(fspFactory != newFactory, "Same value");
        fspFactory = newFactory;
        emit FSPFactoryUpdated(newFactory);
    }
}