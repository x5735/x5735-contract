// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20Receiver.sol";

interface IStargateProxyReceiver is IERC20Receiver {
    error InvalidProxy();

    event SgProxyReceive(address indexed srcFrom, address indexed token, uint256 amount, bytes data);

    function sgProxy() external view returns (address);

    function sgProxyReceive(
        address srcFrom,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}