// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./StakerThena.sol";

contract StakerImpl is StakerThena {
    constructor(address feeCollector)
        StakerThena(feeCollector)
    {       
    }
}