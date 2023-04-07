// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IStargateProxyReceiver.sol";

interface IDisperse is IStargateProxyReceiver {
    error InvalidToken();
    error InsufficientBalance();
    error InvalidParams();
    error InvalidSwapData();

    event Disperse(address indexed token, address[] recipients, uint256[] amounts);
    event Withdraw(address indexed token, address indexed to, uint256 amount);

    struct DisperseParams {
        uint256 amountIn;
        address tokenIn;
        address tokenOut;
        address swapTo;
        bytes swapData;
        address[] recipients;
        uint256[] amounts;
        address refundAddress;
    }

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;

    function disperse(DisperseParams calldata params) external;

    function disperseIntrinsic(DisperseParams calldata params) external;
}