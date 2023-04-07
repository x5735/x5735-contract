// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "./ImpToken.sol";

contract RalpToken is ImpToken {
    constructor() ImpToken(
    
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E),
        address(0x55d398326f99059fF775485246999027B3197955),
        "FUXING DOLLAR",
        "FUD",
        18,
        10000000,
        1000,
        address(0x000000000000000000000000000000000000dEaD),
        address(0xf6Eb0Ee2D035780A883F0F6B2E391d1b9487c947),
        address(0x6A2E26cDe443D135F46D02CA581239826eE38BA9)
    ){
        
    }
}