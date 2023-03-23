// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./ERC20.sol";
import "./Ownable.sol";

////Bitbulls.sol

contract Bitbulls is ERC20,Ownable{
    constructor(address _to) ERC20("Bitbulls", "Bulls") {
        _mint(_to, 1000000000 * 10 ** decimals());
    }


}