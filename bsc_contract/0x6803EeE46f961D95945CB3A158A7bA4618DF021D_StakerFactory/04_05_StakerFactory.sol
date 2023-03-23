// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakerProxy.sol";

contract StakerFactory is Ownable {

    address public implementation;

    event InstanceCreated(address indexed instance);

    function setImplementation(address _implementation) onlyOwner external {
        implementation = _implementation;
    }

    function createInstance() onlyOwner external returns (address) {
        StakerProxy proxy = new StakerProxy(address(this));
        emit InstanceCreated(address(proxy));
        return address(proxy);
    }

}