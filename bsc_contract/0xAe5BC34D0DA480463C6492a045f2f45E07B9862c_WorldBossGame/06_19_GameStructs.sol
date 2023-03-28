// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface GameStructs {
    struct Config {
        uint256 base_hp;
        uint32 hp_scale;
        uint32 lock_lv;
        uint32 lock_percent;
        uint32 lv_reward_percent;
        uint32 prize_percent;
        uint32 attack_cd;
        uint32 escape_cd;
    }

    struct Boss {
        uint256 hp;
        uint64 born_time;
        uint64 attack_time;
        uint64 escape_time;
    }

    struct UserBullet {
        uint256 attacked;
        bool recycled;
        bool kill_reward_claimed;
    }

    struct Level {
        uint256 hp;
        uint256 total_bullet;
        mapping(address => UserBullet) user_bullet;
    }

    struct Round {
        uint256 lv;
        uint256 prize;
        Config config;
        uint32[] prize_config;
        address[] prize_users;
        mapping(address => uint256) prize_claimed;
    }

    struct RoundLevel {
        uint256 roundId;
        uint256 lv;
    }
}