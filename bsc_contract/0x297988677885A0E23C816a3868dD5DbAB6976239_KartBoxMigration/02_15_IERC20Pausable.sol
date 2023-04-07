// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Pausable is IERC20, IERC20Metadata {
    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);
}