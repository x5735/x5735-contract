// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Crocobit is ERC20, Ownable {

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    constructor(address admin) ERC20("Crocobit", "CRT") {
        transferOwnership(admin);
        _mint(admin, 3000000000 * 10 ** decimals());
    }
}