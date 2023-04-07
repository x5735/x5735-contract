// SPDX-License-Identifier: MIT

pragma solidity 0.5.17;

interface IUserStakingPrice {

    // --- Function ---
    function userStakingValue(address user) external view returns (uint256 fee, uint256 totalValue);
}