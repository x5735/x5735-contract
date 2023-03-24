// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiFace DAO token
 * @notice token for using in MF swap contract
 */

contract BSC_TOKEN is ERC20, Ownable {
    constructor() ERC20("USDT Token", "USDT") {}

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @notice Mint tokens to some addresses
     * @param to Address for mint
     * @param amount Amount of tokens for mint
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}