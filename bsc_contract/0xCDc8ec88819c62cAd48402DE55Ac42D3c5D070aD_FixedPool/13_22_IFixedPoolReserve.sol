// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IFixedPoolReserve {

    function recoverTokens(address _token, uint256 _amount) external;

    function recoverTokensFor(address _token, uint256 _amount, address _to) external;

}