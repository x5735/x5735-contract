//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract X2X is ERC20Burnable, Ownable {
    constructor(address _ownerAddress) ERC20("X2X NETWORK", "X2X") Ownable() {
        _mint(_ownerAddress, 800000000 ether);
        _transferOwnership(_ownerAddress);
    }
}