pragma solidity =0.5.16;

import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';

contract Token is ERC20Detailed, ERC20Mintable, Ownable {

    constructor(string memory _name, string memory _symbol, uint8 decimals)
    ERC20Detailed(_name, _symbol, decimals) public {}

}