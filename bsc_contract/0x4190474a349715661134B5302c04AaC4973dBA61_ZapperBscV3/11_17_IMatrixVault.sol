// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMatrixVault is IERC20 {

    function want() external view returns (address);

    function deposit(uint256) external;

    function withdraw(uint256 _shares) external;

}