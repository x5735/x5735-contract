// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin-4.5.0/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("BSC V3 Emissions Dummy", "BSC-V3-MOCK") {
        _mint(0x444D73Ea7bC7C72Ea11638203846dAD632677180, 100 ether);
    }
}