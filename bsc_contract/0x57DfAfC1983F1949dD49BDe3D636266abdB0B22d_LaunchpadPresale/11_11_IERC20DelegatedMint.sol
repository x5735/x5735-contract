// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20DelegatedMint is IERC20 {

    function mint(uint256 amount) external;

    function mintFor(address addr, uint256 amount) external;
}