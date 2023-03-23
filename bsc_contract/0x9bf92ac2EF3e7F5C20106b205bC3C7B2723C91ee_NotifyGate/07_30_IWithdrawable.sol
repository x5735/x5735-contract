// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IWithdrawable {
    event Withdrawn(
        address indexed token,
        address indexed to,
        uint256 indexed value
    );

    /**
     * @dev Event emitted when funds are received by the contract
     */
    event Received(
        address indexed sender,
        address indexed token,
        bytes value,
        bytes data
    );

    function notifyERC20Transfer(
        address token_,
        uint256 value_,
        bytes calldata data_
    ) external returns (bytes4);

    /**
     * @dev Withdraws the given amount of tokens or Ether from the contract
     * @param token_ Address of the token contract to withdraw. If zero address, withdraw Ether.
     * @param to_ Address to send the tokens or Ether to
     * @param amount_ Amount of tokens or Ether to withdraw
     */
    function withdraw(
        address token_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    ) external;
}