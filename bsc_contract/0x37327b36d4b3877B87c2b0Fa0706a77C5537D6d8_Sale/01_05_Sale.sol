// SPDX-License-Identifier: MIT
// GoldQuality

pragma solidity ^0.8.19;

import "IERC20.sol";
import "IPair.sol";
import "Ownable.sol";

contract Sale is Ownable {
    IERC20 public token;
    IPair private pair;
    uint256 public price;

    event PriceChanged(address user, uint256 price);
    event TokensWithdrawn(address user, uint256 amount);
    event CoinsWithdrawn(address user, uint256 amount);
    event TokensPurchased(address indexed user, uint256 coinsAmount, uint256 tokensAmount);

    constructor(
        address _token,
        address _pair
    )
    {
        token = IERC20(_token);
        pair = IPair(_pair);
        price = 0;
    }

    function getPriceInCoins()
    public view
    returns (uint256)
    {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        return reserve1 * price * 1e16 / reserve0;
    }

    function setPrice(uint256 _price)
    external onlyOwner
    {
        require(_price != 0, "Wrong price");
        price = _price;

        emit PriceChanged(_msgSender(), _price);
    }

    function withdrawTokens()
    external onlyOwner
    {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(owner(), amount);

        emit TokensWithdrawn(_msgSender(), amount);
    }

    function withdrawCoins()
    external onlyOwner
    {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);

        emit CoinsWithdrawn(_msgSender(), amount);
    }

    receive()
    external payable
    {
        require(price != 0, "Sales do not work");

        uint256 tokenAmount = msg.value * 1e18 / getPriceInCoins();

        require(token.balanceOf(address(this)) >= tokenAmount, "Not enough tokens to sale");

        token.transfer(_msgSender(), tokenAmount);

        emit TokensPurchased(_msgSender(), msg.value, tokenAmount);
    }
}