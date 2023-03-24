// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

library BotanStruct {
    struct Botan {
        uint32 category;
        BotanRarity rarity; // 1-4
        uint8 breedTimes; // 0-n
        BotanPhase phase; // 1-4
        uint32 dadId;
        uint32 momId;
        uint64 time;
        uint64 blocks;
    }

    enum BotanPhase {
        None,
        Seed,
        Plant
    }

    enum BotanRarity {
        None,
        C,
        R,
        SR,
        SSR
    }
}