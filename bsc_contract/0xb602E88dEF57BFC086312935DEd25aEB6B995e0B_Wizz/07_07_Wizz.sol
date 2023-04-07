// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Wizz is ERC20, ERC20Burnable, Ownable {
    uint256 exchangeRate = 1;
    address public paymentToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; 
    address public currOwner;
    
    constructor() ERC20("WIZZ Ecosystem Coin", "WEC") {
        _mint(address(this), 571000000*10**18);
        currOwner = msg.sender;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function changeExchangeRate(uint256 _exchangeRate) public onlyOwner {
        exchangeRate = _exchangeRate;
    }

    function changePaymentToken(address _paymentToken) public onlyOwner {
        paymentToken = _paymentToken;
    }

    function buyFromToken(uint256 _amount) public {
        IERC20 payToken = IERC20(paymentToken);
        payToken.transferFrom(msg.sender, address(this), _amount * exchangeRate);
        this.transfer(msg.sender, _amount);
    }

    function withdrawPaymentToken() public onlyOwner {
        // token balance
        IERC20 payToken = IERC20(paymentToken);
        uint256 paymentTokenBalance = payToken.balanceOf(address(this));
        payToken.transferFrom(address(this), currOwner, paymentTokenBalance);
    }
}