// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "./ILaunchpadVault.sol";

interface ILaunchpadFeeDecider {
    function calculateFee(address addr, uint256 amount) external view returns (uint256);
}