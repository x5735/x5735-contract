// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITreasury {
    error Treasury__Expired();
    error Treasury__LengthMismatch();
    error Treasury__InvalidBalance();
    error Treasury__InvalidArgument();
    error Treasury__InvalidSignature();
    error Treasury__MistakenTransfer();
    error Treasury__InvalidTokenAddress();
    error Treasury__InvalidFunctionCall();
    error Treasury__UnauthorizedWithdrawal();

    event BalanceInitiated(address indexed operator, uint256 indexed balance);

    function withdraw(
        address token_,
        address to_,
        uint256 value_,
        uint256 amount_, // if withdraw ERC1155
        uint256 deadline_,
        bytes calldata signature_
    ) external;

    function nonces(address account_) external view returns (uint256);
}