// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MultiSigConfirmer.sol";

/// @author The-Poolz contract team
/// @title Smart contract of using multi signature for approval sending transactions.
contract MultiSig is MultiSigConfirmer {
    /// @param Authorized who can votes and initiate mint transaction
    /// @param Token mintable token address
    /// @param MinSignersAmount minimum amount of votes for a successful mint transaction
    constructor(
        address[] memory Authorized,
        address Token,
        uint256 MinSignersAmount
    ) {
        require(Authorized.length >= MinSignersAmount, "Authorized array length must be equal or greater than MinSignersAmount");
        require(Token != address(0), "Token address must be non-zero");
        require(MinSignersAmount > 1, "Minimum signers must be greater than 1");
        for (uint256 index = 0; index < Authorized.length; index++) {
            require(Authorized[index] != address(0), "Invalid Authorized address");
            AuthorizedMap[Authorized[index]] = true;
        }
        TokenAddress = Token;
        MinSigners = MinSignersAmount;
        emit Setup(Authorized, Token, MinSignersAmount);
    }
}
