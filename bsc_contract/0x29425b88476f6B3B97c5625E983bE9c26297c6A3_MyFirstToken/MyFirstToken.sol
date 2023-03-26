/**
 *Submitted for verification at BscScan.com on 2023-03-25
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

contract MyFirstToken {
    string public name = "MyFirstToken";
    string public symbol = "MFT";
    uint256 public totalSupply = 1000000000000000000000000; // 1 million tokens with 18 decimal places
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Not authorized to spend");
        balanceOf[from] -= value;
        allowance[from][msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    address public feeWallet = 0x391c49eEAEf98C29373464E5e3709fB552e86aD3;
    uint256 public feePercentage = 10;

    function calculateFee(uint256 value) public view returns (uint256) {
        return value * feePercentage / 100;
    }

    function transferWithFee(address to, uint256 value) public returns (bool success) {
        uint256 fee = calculateFee(value);
        require(balanceOf[msg.sender] >= value + fee, "Insufficient balance");
        balanceOf[msg.sender] -= value + fee;
        balanceOf[feeWallet] += fee;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        emit Transfer(msg.sender, feeWallet, fee);
        return true;
    }
}