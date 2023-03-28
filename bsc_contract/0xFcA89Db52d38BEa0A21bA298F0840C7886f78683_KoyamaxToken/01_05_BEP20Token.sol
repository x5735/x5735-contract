pragma solidity >=0.6.0;

import "./ERC20.sol";

contract KoyamaxToken is ERC20 {
    constructor(uint256 initialSupply) public ERC20("KoyamaxToken", "KYMX") {
        _mint(msg.sender, initialSupply);
    }
}