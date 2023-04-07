// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20Receiver {
    event OnReceiveERC20(address indexed token, address indexed to, uint256 amount);

    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external;
}