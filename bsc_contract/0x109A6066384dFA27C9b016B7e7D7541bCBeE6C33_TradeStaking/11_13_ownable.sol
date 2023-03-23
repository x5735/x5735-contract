// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Ownable  {
    address public owner;
    address public executor;
    modifier onlyExecutor() {
        require(executor == msg.sender, "Executable: caller is not the executor");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        owner = msgSender;
        executor = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public  onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    function setExecutor(address _executor) onlyOwner external {
        executor = _executor;
    }
}