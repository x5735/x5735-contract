// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./StakerFactory.sol";

contract StakerProxy is Proxy {

    address immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function _implementation() override internal view returns (address) {
        return StakerFactory(factory).implementation();
    }

    function _beforeFallback() override internal virtual {
        require(msg.sender == StakerFactory(factory).owner(), "StakerProxy: NO_ACCESS");
    }

    receive() external payable virtual override {
        //_fallback();
    }

}