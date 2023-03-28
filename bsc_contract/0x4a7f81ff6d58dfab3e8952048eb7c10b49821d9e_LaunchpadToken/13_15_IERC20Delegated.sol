// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "./IERC20DelegatedBurn.sol";
import "./IERC20DelegatedMint.sol";

interface IERC20Delegated is IERC20DelegatedBurn, IERC20DelegatedMint {}