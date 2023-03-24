/**
 *Submitted for verification at BscScan.com on 2023-03-24
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ShibaARBInu {
    string public name = "Shiba ARB Inu";
    string public symbol = "ARBSHIB";
    uint256 public totalSupply = 1000000000 * 10**18;
    uint8 public decimals = 18;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    uint256 public lastBurnTime;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed burner, uint256 value);

    constructor() {
        balances[msg.sender] = totalSupply;
        lastBurnTime = block.timestamp;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "Insufficient balance");
        require(_to != address(0), "Invalid recipient");
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balances[_from] >= _value, "Insufficient balance");
        require(allowed[_from][msg.sender] >= _value, "Not enough allowance");
        require(_to != address(0), "Invalid recipient");

        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function burn() public {
        require(block.timestamp - lastBurnTime >= 90 days, "Cannot burn yet");
        uint256 burnAmount = totalSupply / 100;
        totalSupply -= burnAmount;
        balances[msg.sender] -= burnAmount;
        lastBurnTime = block.timestamp;
        emit Burn(msg.sender, burnAmount);
    }
}