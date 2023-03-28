//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol"; // Import the ERC20 interface

contract TokenDuster {
    
    address public tokenAddress; // Address of the BSC token to be dusted
    uint public dustAmount; // Amount of token to be dusted
    uint public numAddresses; // Number of addresses to receive dust
    address[] public addresses; // Array of recipient addresses
    mapping(address => bool) public hasReceivedDust; // Mapping to keep track of who has received dust
    
    constructor(address _tokenAddress, uint _dustAmount, uint _numAddresses) {
        tokenAddress = _tokenAddress;
        dustAmount = _dustAmount;
        numAddresses = _numAddresses;
        addresses = new address[](numAddresses);
    }
    
    function addAddresses(address[] memory _addresses) external {
        require(_addresses.length <= numAddresses, "Cannot add more than numAddresses");
        for(uint i = 0; i < _addresses.length; i++) {
            addresses[i] = _addresses[i];
        }
    }
    
    function dustToken() external {
        IERC20 token = IERC20(tokenAddress);
        uint balance = token.balanceOf(address(this));
        require(balance >= dustAmount * numAddresses, "Insufficient token balance in contract");
        for(uint i = 0; i < numAddresses; i++) {
            if(!hasReceivedDust[addresses[i]]) {
                hasReceivedDust[addresses[i]] = true;
                token.transfer(addresses[i], dustAmount);
            }
        }
    }
}