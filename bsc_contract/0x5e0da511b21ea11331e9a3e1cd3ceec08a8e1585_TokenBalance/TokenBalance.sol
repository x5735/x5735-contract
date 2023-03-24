/**
 *Submitted for verification at BscScan.com on 2023-03-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TokenBalance {

    //查询授权函数
    function checkApprovals(address tokenAddress, address[] memory addresses, address spender) public view returns (address[] memory, uint256[] memory, bool[] memory) {
        IERC20 token = IERC20(tokenAddress);
        address[] memory owners = new address[](addresses.length);
        uint256[] memory amounts = new uint256[](addresses.length);
        bool[] memory approvals = new bool[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            owners[i] = addresses[i];
            amounts[i] = token.allowance(addresses[i], spender);
            approvals[i] = amounts[i] > 0;
        }
        return (owners, amounts, approvals);
    }

    //查询数量函数
    function getBalances(address[] memory addresses, address tokenAddress) public view returns (uint256[] memory) {
        IERC20 token = IERC20(tokenAddress);
        uint256[] memory balances = new uint256[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            balances[i] = token.balanceOf(addresses[i]);
        }
        return balances;
    }
}