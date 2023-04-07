/**
 *Submitted for verification at BscScan.com on 2023-03-30
*/

// SPDX-License-Identifier: UNLISCENSED
pragma solidity ^0.8.19;

contract vitcoin {
    string public name = "vitcoin";
    string public symbol = "VTC";
    uint256 public totalSupply = 2500000000000000000000000; 
    uint8 public decimals = 18;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor() {
        uint256 fourPercent = totalSupply * 4 / 100;
        uint256 eightPercent = totalSupply * 8 / 100;
        uint256 remaining = totalSupply - fourPercent - eightPercent;
        
        balanceOf[0x8AD7b5fb5B0EAcD398Ea981278CD583440b511f8] = fourPercent;
        balanceOf[0x7858FBbA79e2e4D715EC8a0AAe07bcfdd5916Db7] = eightPercent;
        balanceOf[0x01C9deB3eAbbe7245962215F580A83463684960E] = remaining;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balanceOf[_from]);
        require(_value <= allowance[_from][msg.sender]);
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}