// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";

contract ClaimContract {
    address public tokenAddress;
    mapping(address => uint256) public balances;

    event Claimed(address indexed user, uint256 amount);

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function claim() external {
        uint256 balance = IERC20(tokenAddress).balanceOf(msg.sender);
        require(balance > 0, "Sender has no balance to claim");
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), balance);
        require(success, "Transfer of token failed");

        balances[msg.sender] += balance;
        emit Claimed(msg.sender, balance);
    }
}