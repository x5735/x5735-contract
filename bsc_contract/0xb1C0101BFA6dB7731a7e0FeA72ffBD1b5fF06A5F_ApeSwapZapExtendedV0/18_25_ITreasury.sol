// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury {
    function adminAddress() external view returns (address);

    function banana() external view returns (IERC20);

    function bananaReserves() external view returns (uint256);

    function buy(uint256 _amount) external;

    function buyFee() external view returns (uint256);

    function emergencyWithdraw(uint256 _amount) external;

    function goldenBanana() external view returns (IERC20);

    function goldenBananaReserves() external view returns (uint256);

    function maxBuyFee() external view returns (uint256);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function sell(uint256 _amount) external;

    function setAdmin(address _adminAddress) external;

    function setBuyFee(uint256 _fee) external;

    function transferOwnership(address newOwner) external;
}