// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract NOVA is ERC20Upgradeable {
    constructor() public {
        __ERC20_init("Co-rich Community Token", "NOVA");
        _mint(msg.sender, 21000000 ether);
    }
}