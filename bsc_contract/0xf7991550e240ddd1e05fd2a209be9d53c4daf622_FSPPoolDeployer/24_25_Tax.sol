// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

struct Tax {
    uint256 stake;
    uint256 burn;
    uint256 liquidity;
    uint256 pension;
    uint256 legal;
    uint256 team;
    uint256 divtracker;
    uint256 partition;
    uint256 k401;
}

/* 
* buyStake
* sellStake
* buyBurn
* sellBurn
* buyLiquidity
* sellLiquidity
* buyPension
* sellPension
* buyLegal
* sellLegal
* buyTeam
* sellTeam
* buyDiv
* sellDiv
* buyBurn
* sellBurn
* Partition
* 401K
*/