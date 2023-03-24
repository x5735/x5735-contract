// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "../libraries/BotanStruct.sol";

interface IGeneScience {
    function unbox(
        BotanStruct.Botan memory seed,
        BotanStruct.Botan calldata dad,
        BotanStruct.Botan calldata mom
    ) external view returns (BotanStruct.Botan memory);

    function grow(
        BotanStruct.Botan memory seed,
        BotanStruct.Botan calldata dad,
        BotanStruct.Botan calldata mom
    ) external view returns (BotanStruct.Botan memory);
}