// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;
import "./GameStructs.sol";

interface IGame is GameStructs {
    function roundOf(
        uint256 roundId_
    )
        external
        view
        returns (
            uint256 _lv,
            uint256 _prize,
            Config memory _config,
            uint32[] memory _prize_config,
            address[] memory _prize_users
        );

    function canRecycleLevelBullet(address user_) external view returns (bool);

    function levelBulletOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    )
        external
        view
        returns (
            uint256 recycled_bullet,
            uint256 unused_bullet,
            uint256 recycled_total,
            uint256 user_bullet
        );

    function preRoundLevelOf(address user_) external view returns (uint256 _roundId, uint256 _lv);

    function canClaimPrizeReward(address user) external view returns (bool);

    function userPrizeRewardOf(
        uint256 roundId_,
        address user
    ) external view returns (uint256 reward);

    function killRewardRoundLevelsOf(address user) external view returns (RoundLevel[] memory _lvs);

    function canClaimKillReward(
        uint256 roundId_,
        uint256 lv_,
        address user
    ) external view returns (bool);

    function killRewardOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    ) external view returns (uint256 total_reward);

    function theLastLevel() external view returns (uint256 roundId_, uint256 lv_);

    function levelOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    ) external view returns (uint256 total_bullet, uint256 user_bullet, uint256 boss_hp);

    function attackedLvsOf(
        uint256 roundId_,
        address user
    ) external view returns (uint256[] memory lvs);
}