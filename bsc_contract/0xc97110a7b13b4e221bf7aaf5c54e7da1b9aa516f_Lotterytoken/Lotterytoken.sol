/**
 *Submitted for verification at BscScan.com on 2023-03-26
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lotterytoken {
    string public name = "Lottery Token";
    string public symbol = "LTRY";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address private owner;
    bool public isSwapAllowed;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        owner = msg.sender;
        totalSupply = 777777 * (10 ** uint256(decimals));
        balanceOf[owner] = totalSupply;
        isSwapAllowed = false;
    }

    function setSwapAllowed(bool _isSwapAllowed) external {
        require(msg.sender == owner, "Only the owner can change this setting");
        isSwapAllowed = _isSwapAllowed;
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(isSwapAllowed || msg.sender == owner, "Swapping is not allowed");
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(isSwapAllowed || from == owner, "Swapping is not allowed");
        require(value <= allowance[from][msg.sender], "Transfer amount exceeds allowance");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Cannot transfer to the zero address");
        require(balanceOf[from] >= value, "Insufficient balance");

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
    }
}