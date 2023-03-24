// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

library LandStruct {
    struct Land {
        LandRarity rarity; //1-4
        uint32 category;
        uint64 time;
    }

    enum LandRarity {
        None,
        C,
        R,
        SR,
        SSR
    }
}