// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CrescentWalletController is Ownable {

    address implementation;

    constructor(address _implementation){
        implementation = _implementation;
    }

    function setImplementation(address _implementation) public onlyOwner {
        implementation = _implementation;
    }

    function getImplementation() public view returns (address) {
        return implementation;
    }
}