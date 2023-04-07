// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArcusToken is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public controllers;

    uint256 private constant MAX_SUPPLY = 85_000_000 * 10**18;

    constructor() ERC20("Arcus Token", "ARCUS") {
        _mint(msg.sender, 1_000 * 10**18);
        controllers[msg.sender] = true;
    }

    function mint(address to, uint256 amount) external onlyController {
        require(totalSupply() + amount <= MAX_SUPPLY, "Maximum supply has been reached");
        _mint(to, amount);
    }

    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }

    modifier onlyController() {
        require(controllers[msg.sender], "Only controllers can call this function");
        _;
    }
}