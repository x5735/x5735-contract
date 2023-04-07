// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBiswapfarm {
    function deposit(uint256 _pid, uint256 _wantAmt) external;

    function withdraw(uint256 _pid, uint256 _wantAmt) external;
}