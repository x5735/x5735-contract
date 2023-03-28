// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20DelegatedBurn is IERC20 {

    function burn(uint256 amount) external;

    function burnFor(address addr, uint256 amount) external;
}