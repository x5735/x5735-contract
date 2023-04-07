// SPDX-License-Identifier: MIT
// GoldQuality

pragma solidity ^0.8.19;

import "IERC20.sol";
import "Ownable.sol";

contract Burn is Ownable {
    IERC20 public token;

    event Burned(uint256 amount);

    constructor(address _token)
    {
        token = IERC20(_token);
    }

    function burn()
    external onlyOwner
    {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens");

        token.burn(amount);

        emit Burned(amount);
    }
}