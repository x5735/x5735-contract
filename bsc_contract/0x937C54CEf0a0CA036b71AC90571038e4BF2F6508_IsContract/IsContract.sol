/**
 *Submitted for verification at BscScan.com on 2023-03-25
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// address 0x937C54CEf0a0CA036b71AC90571038e4BF2F6508
contract IsContract {
    constructor() {}

    function isContract(address account) public view returns (bool) {
        return account.code.length > 0;
    }
}