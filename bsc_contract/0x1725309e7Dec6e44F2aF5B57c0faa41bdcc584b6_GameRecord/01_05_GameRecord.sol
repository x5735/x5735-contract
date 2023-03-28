// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "./Constant.sol";
import "./IGame.sol";
import "./MultiStaticCall.sol";

interface IBullet {
    function bulletOf(address user) external view returns (uint256);
}

contract GameRecord is MultiStaticCall {
    struct LevelDetail {
        uint256 lv;
        uint256 user_bullet;
        uint256 user_damage;
    }

    function claimableRewardOf(
        IGame game,
        address user
    ) public view returns (uint256 total_reward) {
        total_reward = 0;
        (uint256 pre_roundId, uint256 pre_lv) = game.preRoundLevelOf(user);
        if (game.canRecycleLevelBullet(user)) {
            (, , uint256 recycled_total, ) = game.levelBulletOf(pre_roundId, pre_lv, user);
            total_reward += recycled_total;
        }

        if (game.canClaimPrizeReward(user)) {
            uint256 prize_reward = game.userPrizeRewardOf(pre_roundId, user);
            total_reward += prize_reward;
        }

        GameStructs.RoundLevel[] memory _lvs = game.killRewardRoundLevelsOf(user);
        for (uint i = 0; i < _lvs.length; i++) {
            if (game.canClaimKillReward(_lvs[i].roundId, _lvs[i].lv, user)) {
                uint256 kill_reward = game.killRewardOf(_lvs[i].roundId, _lvs[i].lv, user);
                total_reward += kill_reward;
            }
        }
    }

    function bulletAndClaimableOf(
        address game,
        address user
    ) public view returns (uint256 bullet_, uint256 claimable_) {
        bullet_ = IBullet(game).bulletOf(user);
        claimable_ = claimableRewardOf(IGame(game), user);
    }

    function levelDetailOf(
        IGame game,
        uint256 roundId_,
        uint256 lv_,
        address user_
    ) public view returns (LevelDetail memory detail) {
        (uint256 _lv, , , , ) = game.roundOf(roundId_);

        (uint256 _cur_roundId, ) = game.theLastLevel();

        if (roundId_ > _cur_roundId || lv_ > _lv) {
            detail = LevelDetail(0, 0, 0);
        } else {
            (uint256 total_bullet, uint256 user_bullet, uint256 boss_hp) = game.levelOf(
                roundId_,
                lv_,
                user_
            );
            if (boss_hp <= total_bullet) {
                uint256 _damage = (boss_hp * user_bullet) / total_bullet;
                detail = LevelDetail(lv_, user_bullet, _damage);
            } else {
                detail = LevelDetail(lv_, user_bullet, 0);
            }
        }
    }

    function levelDetailListOf(
        IGame game,
        uint256 roundId_,
        address user
    ) public view returns (LevelDetail[] memory list) {
        uint256[] memory lvs = game.attackedLvsOf(roundId_, user);
        list = new LevelDetail[](lvs.length);
        for (uint i = 0; i < lvs.length; i++) {
            list[i] = levelDetailOf(game, roundId_, lvs[i], user);
        }
    }
}