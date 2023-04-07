// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "./IGame.sol";
import "./Bullet.sol";
import "./GamePauseable.sol";

contract WorldBossGame is Bullet, GamePauseable, AutomationCompatible, IGame {
    event NewBoss(
        uint256 roundId,
        uint256 lv,
        uint256 hp,
        uint256 born_time,
        uint256 attack_time,
        uint256 escape_time
    );
    event PreAttack(address user, uint256 roundId, uint256 lv, uint256 bullet_mount);
    event Attack(address user, uint256 roundId, uint256 lv, uint256 bullet_mount);
    event Killed(uint256 roundId, uint256 lv, uint256 boss_hp, uint256 total_bullet);
    event Escaped(uint256 roundId, uint256 lv, uint256 boss_hp, uint256 total_bullet);

    event RecycleLevelBullet(address user, uint256 roundId, uint256 lv, uint256 amount);
    event ClaimKillReward(address user, uint256 roundId, uint256 lv, uint256 amount);
    event ClaimPrizeReward(address user, uint256 roundId, uint256 amount);
    event PrizeWinner(uint256 roundId, address[] winners);
    event IncreasePrize(uint256 roundId, address user, uint256 amount);

    uint256 public roundId;
    Config private global_config;
    uint32[] private global_prize_config;
    uint64 public born_cd_pre_attack;
    uint64 public born_cd_attack;
    Boss public boss;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(uint256 => Level)) private levels;
    mapping(address => RoundLevel) private userPreRoundLevel;
    mapping(address => RoundLevel[]) private killRewardRoundLevels;
    /**       user              roundId     levels */
    mapping(address => mapping(uint256 => uint256[])) private attacked_lvs;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address admin_,
        address system_wallet_,
        address fee_wallet_,
        address token_,
        uint256 fee_
    ) public initializer {
        _initOwnable(owner_, admin_);
        _initBullet(token_, system_wallet_, fee_wallet_, fee_);
        born_cd_pre_attack = 300;
        born_cd_attack = 1800;
        global_config = Config(3000000000000000000000, 10900, 3, 4000, 800, 100, 300, 21300);
        global_prize_config = [800, 800, 800, 2500, 5100];
    }

    function setConfig(
        uint256 base_hp_,
        uint32 hp_scale,
        uint32 lock_lv_,
        uint32 lock_percent_,
        uint32 lv_reward_percent_,
        uint32 prize_percent_,
        uint32 attack_cd,
        uint32 escape_cd,
        uint32[] memory prize_config_
    ) external onlyOwner {
        require(base_hp_ > 0);
        require(hp_scale > 0);
        require(lock_lv_ > 0);
        require(lock_percent_ > 0 && lock_percent_ < Constant.E4);
        require(lv_reward_percent_ > 0 && lv_reward_percent_ < Constant.E4);
        require(prize_percent_ > 0 && prize_percent_ < Constant.E4);
        require(attack_cd > 0);
        require(escape_cd > 0);
        global_config = Config(
            base_hp_,
            hp_scale,
            lock_lv_,
            lock_percent_,
            lv_reward_percent_,
            prize_percent_,
            attack_cd,
            escape_cd
        );
        uint256 _total;
        for (uint i = 0; i < prize_config_.length; i++) {
            _total += prize_config_[i];
        }
        require(_total == Constant.E4, "The sum of the prize pool shares is not 100%");
        global_prize_config = prize_config_;
    }

    function _cloneConfigToRound() internal {
        Round storage round = rounds[roundId];
        require(round.config.base_hp == 0);
        round.config.base_hp = global_config.base_hp;
        round.config.hp_scale = global_config.hp_scale;
        round.config.lock_lv = global_config.lock_lv;
        round.config.lock_percent = global_config.lock_percent;
        round.config.lv_reward_percent = global_config.lv_reward_percent;
        round.config.prize_percent = global_config.prize_percent;
        round.config.attack_cd = global_config.attack_cd;
        round.config.escape_cd = global_config.escape_cd;

        round.prize_config = global_prize_config;
    }

    function startGame() external onlyAdmin whenGameNotPaused {
        require(global_config.base_hp > 0);
        roundId = 1;
        rounds[roundId].lv = 1;
        _cloneConfigToRound();
        _bornBoss();
    }

    function _increaseHp() internal view returns (uint256 _hp) {
        Config storage _round_config = rounds[roundId].config;
        if (rounds[roundId].lv == 1) {
            _hp = _round_config.base_hp;
        } else {
            _hp = (boss.hp * _round_config.hp_scale) / Constant.E4;
        }
    }

    function _bornBoss() internal {
        Config storage _round_config = rounds[roundId].config;
        uint256 _hp = _increaseHp();
        uint256 _born_time;

        if (rounds[roundId].lv > 1) {
            Level storage pre_lv = levels[roundId][rounds[roundId].lv - 1];
            if (pre_lv.total_bullet > pre_lv.hp) {
                _born_time =
                    block.timestamp +
                    born_cd_pre_attack -
                    (block.timestamp % born_cd_pre_attack);
            } else {
                _born_time = block.timestamp + born_cd_attack - (block.timestamp % born_cd_attack);
            }
        } else {
            _born_time = block.timestamp + born_cd_attack - (block.timestamp % born_cd_attack);
        }

        uint256 _attack_time = _born_time + _round_config.attack_cd;
        uint256 _escape_time = _attack_time + _round_config.escape_cd;
        boss = Boss(_hp, uint64(_born_time), uint64(_attack_time), uint64(_escape_time));
        levels[roundId][rounds[roundId].lv].hp = _hp;
        emit NewBoss(
            roundId,
            rounds[roundId].lv,
            boss.hp,
            boss.born_time,
            boss.attack_time,
            boss.escape_time
        );
    }

    function _frozenLevelReward(uint256 roundId_) internal {
        Config storage _round_config = rounds[roundId_].config;
        uint256 _lv_reward = (boss.hp * _round_config.lv_reward_percent) / Constant.E4;
        _addFrozenBullet(_lv_reward);
    }

    function preAttack(
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
    ) external whenGameNotPaused {
        _preAttack(msg.sender, roundId_, lv_, bullet_amount_);
    }

    function _preAttack(
        address user_,
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
    ) internal {
        require(roundId == roundId_, "invalid roundId_");
        require(rounds[roundId].lv == lv_, "invalid lv_");
        require(block.timestamp > boss.born_time, "boss isn't born yet");
        require(block.timestamp <= boss.attack_time, "invalid time");
        _autoClaim(user_);
        _pushRoundLevel(user_);
        _reduceBullet(user_, bullet_amount_);
        Level storage level = levels[roundId_][lv_];
        level.user_bullet[user_].attacked += bullet_amount_;
        level.total_bullet += bullet_amount_;
        _updatePrizeUser(user_, bullet_amount_);
        emit PreAttack(user_, roundId_, lv_, bullet_amount_);
    }

    function attack(
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
    ) external whenGameNotPaused {        
        _attack(msg.sender, roundId_, lv_, bullet_amount_);
    }

    function decideEscapedOrDead() public whenGameNotPaused {
        Level storage level = levels[roundId][rounds[roundId].lv];
        if (boss.hp <= level.total_bullet) {
            require(block.timestamp > boss.attack_time, "invalid time");
            _dead();
        } else {
            require(block.timestamp > boss.escape_time, "invalid time");
            _escape();
        }
    }

    function checkUpkeep(
        bytes calldata /**checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        performData = bytes("");

        if (!isPausing && roundId > 0) {
            Level storage level = levels[roundId][rounds[roundId].lv];
            if (boss.hp <= level.total_bullet) {
                // boss dead
                upkeepNeeded = block.timestamp > boss.attack_time;
            } else {
                upkeepNeeded = block.timestamp > boss.escape_time;
            }
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        decideEscapedOrDead();
    }

    /**
     * on boss dead
     */
    function _dead() internal {
        emit Killed(
            roundId,
            rounds[roundId].lv,
            boss.hp,
            levels[roundId][rounds[roundId].lv].total_bullet
        );
        _frozenLevelReward(roundId);
        _frozenPrizeReward(roundId);
        _nextLevel();
    }

    /**
     * on boss escaped
     */
    function _escape() internal {
        require(block.timestamp > boss.escape_time);
        Level storage level = levels[roundId][rounds[roundId].lv];
        require(boss.hp > level.total_bullet);
        _unfrozenLevelRewardAndClaimBulletToSystem();
        emit Escaped(roundId, rounds[roundId].lv, boss.hp, level.total_bullet);
        emit PrizeWinner(roundId, rounds[roundId].prize_users);
        _nextRound();
    }

    function _attack(
        address user_, 
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
        ) internal {
        require(roundId == roundId_, "invalid roundId_");
        require(rounds[roundId].lv == lv_, "invalid lv_");
        require(block.timestamp > boss.attack_time, "invalid time");
        require(block.timestamp <= boss.escape_time, "boss escaped");
        Level storage level = levels[roundId_][lv_];
        require(boss.hp > level.total_bullet, "boss was dead");

        if (bullet_amount_ > boss.hp - level.total_bullet) {
            bullet_amount_ = boss.hp - level.total_bullet;
        }        
        _autoClaim(user_);
        _pushRoundLevel(user_);
        _reduceBullet(user_, bullet_amount_);
        level.user_bullet[user_].attacked += bullet_amount_;
        level.total_bullet += bullet_amount_;
        _updatePrizeUser(user_, bullet_amount_);
        emit Attack(user_, roundId, rounds[roundId].lv, bullet_amount_);
        if (level.total_bullet >= boss.hp) {
            _dead();
        }
    }

    function _pushRoundLevel(address user_) internal {
        if (levels[roundId][rounds[roundId].lv].user_bullet[user_].attacked > 0) return;
        attacked_lvs[user_][roundId].push(rounds[roundId].lv);
        userPreRoundLevel[user_].roundId = roundId;
        userPreRoundLevel[user_].lv = rounds[roundId].lv;
        killRewardRoundLevels[user_].push(RoundLevel(roundId, rounds[roundId].lv));
    }

    function autoClaim() external whenGameNotPaused {
        _autoClaim(msg.sender);
    }

    function _autoClaim(address user_) internal {
        if (canRecycleLevelBullet(user_)) {
            _recycleLevelBullet(user_);
        }

        if (canClaimPrizeReward(user_)) {
            _claimPrizeReward(user_);
        }

        RoundLevel[] memory kr_lvs = killRewardRoundLevels[user_];
        for (uint i = 0; i < kr_lvs.length; i++) {
            if (canClaimKillReward(kr_lvs[i].roundId, kr_lvs[i].lv, user_)) {
                _claimKillReward(user_, kr_lvs[i].roundId, kr_lvs[i].lv);
            } else {
                if (roundId > kr_lvs[i].roundId) {
                    _removeFromKillRewardRoundLevel(user_, kr_lvs[i].roundId, kr_lvs[i].lv);
                }
            }
        }
    }

    function _frozenPrizeReward(uint256 roundId_) internal {
        Config storage _round_config = rounds[roundId_].config;
        uint256 _add_prize = (boss.hp * _round_config.prize_percent) / Constant.E4;
        rounds[roundId].prize += _add_prize;
        _addFrozenBullet(_add_prize);
    }

    function _nextLevel() internal {
        delete rounds[roundId].prize_users;
        rounds[roundId].lv++;
        _bornBoss();
    }

    function canRecycleLevelBullet(address user) public view returns (bool) {
        uint256 roundId_ = userPreRoundLevel[user].roundId;
        uint256 lv_ = userPreRoundLevel[user].lv;
        if (rounds[roundId_].lv == lv_) return false;
        Level storage level = levels[roundId_][lv_];
        if (level.user_bullet[user].attacked == 0) return false;
        if (level.user_bullet[user].recycled) return false;
        return true;
    }

    function levelBulletOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    )
        public
        view
        returns (
            uint256 recycled_bullet,
            uint256 unused_bullet,
            uint256 recycled_total,
            uint256 user_bullet
        )
    {
        Level storage level = levels[roundId_][lv_];
        Config storage _round_config = rounds[roundId_].config;
        user_bullet = level.user_bullet[user_].attacked;
        if (level.total_bullet >= level.hp) {
            uint256 _damage = (level.hp * user_bullet) / level.total_bullet;
            if (user_bullet > _damage) unused_bullet = user_bullet - _damage;
            recycled_bullet = (_damage * (Constant.E4 - _round_config.lock_percent)) / Constant.E4;
            recycled_total = unused_bullet + recycled_bullet;
        }
    }

    function _recycleLevelBullet(address user_) internal {
        uint256 roundId_ = userPreRoundLevel[user_].roundId;
        uint256 lv_ = userPreRoundLevel[user_].lv;
        Level storage level = levels[roundId_][lv_];
        (, , uint256 total, ) = levelBulletOf(roundId_, lv_, user_);
        level.user_bullet[user_].recycled = true;
        _addBullet(user_, total);
        emit RecycleLevelBullet(user_, roundId_, lv_, total);
    }

    function canClaimKillReward(
        uint256 roundId_,
        uint256 lv_,
        address user
    ) public view returns (bool) {
        Config storage _round_config = rounds[roundId_].config;
        if (rounds[roundId_].lv <= lv_ + _round_config.lock_lv) return false;
        Level storage level = levels[roundId_][lv_];
        if (level.user_bullet[user].attacked == 0) return false;
        if (level.user_bullet[user].kill_reward_claimed) return false;
        return true;
    }

    function killRewardOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    ) public view returns (uint256 total_reward) {
        Config storage _round_config = rounds[roundId_].config;
        require(rounds[roundId_].lv > lv_ + _round_config.lock_lv);
        if (rounds[roundId_].lv > lv_ + _round_config.lock_lv) {
            Level storage level = levels[roundId_][lv_];
            uint256 _damage = (level.hp * level.user_bullet[user_].attacked) / level.total_bullet;
            total_reward =
                (_damage * (_round_config.lock_percent + _round_config.lv_reward_percent)) /
                Constant.E4;
        }
    }

    function _claimKillReward(address user_, uint256 roundId_, uint256 lv_) internal {
        uint256 total_reward = killRewardOf(roundId_, lv_, user_);
        Level storage level = levels[roundId_][lv_];
        level.user_bullet[user_].kill_reward_claimed = true;
        _addBullet(user_, total_reward);
        emit ClaimKillReward(user_, roundId_, lv_, total_reward);
        _removeFromKillRewardRoundLevel(user_, roundId_, lv_);
    }

    function _removeFromKillRewardRoundLevel(address user_, uint256 roundId_, uint256 lv_) internal {
        uint256 index = 0;
        bool _to_remove = false;
        RoundLevel[] storage _lvs = killRewardRoundLevels[user_];
        for (uint i = 0; i < _lvs.length; i++) {
            if (_lvs[i].roundId == roundId_ && _lvs[i].lv == lv_) {
                index = i;
                _to_remove = true;
            }
        }
        if (_to_remove) {
            _lvs[index] = _lvs[_lvs.length - 1];
            _lvs.pop();
        }
    }

    function _unfrozenLevelRewardAndClaimBulletToSystem() internal {
        uint256 _lastLv = rounds[roundId].lv;
        Config storage _round_config = rounds[roundId].config;
        for (uint i = 1; i <= _round_config.lock_lv; i++) {
            if (_lastLv > i) {
                uint256 _boss_hp = levels[roundId][_lastLv - i].hp;
                // //unfrozen level reward
                uint256 _lv_reward = (_boss_hp * _round_config.lv_reward_percent) / Constant.E4;
                _reduceFrozenBullet(_lv_reward);
                //claim locked bullet to system
                _addSystemBullet(_boss_hp * _round_config.lock_percent);
            } else {
                break;
            }
        }
    }

    function _nextRound() internal {
        roundId++;
        rounds[roundId].lv = 1;
        _cloneConfigToRound();
        _bornBoss();
        rounds[roundId].prize = _leftPrizeRewardOf(roundId - 1);
    }

    function canClaimPrizeReward(address user) public view returns (bool) {
        uint256 roundId_ = userPreRoundLevel[user].roundId;

        if (roundId == roundId_) return false;

        Round storage round = rounds[roundId_];
        if (round.prize_claimed[user] > 0) return false;

        Level storage level = levels[roundId_][rounds[roundId_].lv];
        if (level.user_bullet[user].attacked == 0) return false;

        return true;
    }

    function userPrizeRewardOf(
        uint256 roundId_,
        address user
    ) public view returns (uint256 reward) {
        if (roundId_ == roundId) reward = 0;
        Round storage round = rounds[roundId_];
        address[] storage prize_users = round.prize_users;
        uint32[] storage prize_config = round.prize_config;
        uint256 offset = prize_config.length - prize_users.length;
        for (uint256 i = 0; i < prize_users.length; i++) {
            if (user == prize_users[i]) {
                reward += (round.prize * prize_config[i + offset]) / Constant.E4;
            }
        }

        Level storage level = levels[roundId_][round.lv];
        reward += level.user_bullet[user].attacked;
    }

    function prizeWinnersOf(
        uint256 roundId_
    ) public view returns (address[] memory users, uint256 prize, uint32[] memory prize_config) {
        Round storage round = rounds[roundId_];
        address[] storage prize_users = round.prize_users;
        users = prize_users;
        prize = round.prize;
        prize_config = round.prize_config;
    }

    function _leftPrizeRewardOf(uint256 roundId_) internal view returns (uint256 left) {
        require(roundId_ < roundId);
        Round storage round = rounds[roundId_];
        address[] storage prize_users = round.prize_users;
        uint32[] storage prize_config = round.prize_config;
        uint256 length = prize_config.length - prize_users.length;
        uint256 _left_percent;
        for (uint256 i = 0; i < length; i++) {
            _left_percent += prize_config[i];
        }
        left = (round.prize * _left_percent) / Constant.E4;
    }

    function _claimPrizeReward(address user_) internal {
        uint256 roundId_ = userPreRoundLevel[user_].roundId;
        uint256 _reward = userPrizeRewardOf(roundId_, user_);
        rounds[roundId_].prize_claimed[user_] = _reward;
        _addBullet(user_, _reward);
        emit ClaimPrizeReward(user_, roundId_, _reward);
    }

    function increasePrize(uint256 amount) external payable nonReentrant whenGameNotPaused {
        require(roundId > 0, "game don't start");
        if (token == address(0)) {
            require(amount == msg.value, "invalid msg.value");
        } else {
            require(0 == msg.value, "invalid msg.value");
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        }
        rounds[roundId].prize += amount;
        emit IncreasePrize(roundId, msg.sender, amount);
    }

    function _updatePrizeUser(address user_, uint256 bullet_) internal {
        Round storage round = rounds[roundId];
        if (block.timestamp + Constant.PRIZE_BLACK_TIME > boss.escape_time) return;

        if (bullet_ >= boss.hp / 100) {
            address[] storage prize_users = round.prize_users;
            if (prize_users.length < round.prize_config.length) {
                prize_users.push(user_);
            } else {
                for (uint i = 1; i < prize_users.length; i++) {
                    prize_users[i - 1] = prize_users[i];
                }
                prize_users[prize_users.length - 1] = user_;
            }
            require(prize_users.length <= round.prize_config.length);
        }
    }

    function updateBornCD(uint64 born_cd_pre_attack_, uint64 born_cd_attack_) external onlyAdmin {
        born_cd_pre_attack = born_cd_pre_attack_;
        born_cd_attack = born_cd_attack_;
    }

    function _beforeWithdraw() internal override {
        _autoClaim(msg.sender);
    }

    function levelOf(
        uint256 roundId_,
        uint256 lv_,
        address user_
    ) public view returns (uint256 total_bullet, uint256 user_bullet, uint256 boss_hp) {
        total_bullet = levels[roundId_][lv_].total_bullet;
        user_bullet = levels[roundId_][lv_].user_bullet[user_].attacked;
        boss_hp = levels[roundId_][lv_].hp;
    }

    function theLastLevel() public view returns (uint256 roundId_, uint256 lv_) {
        roundId_ = roundId;
        lv_ = rounds[roundId].lv;
    }

    function onGameResume() internal virtual override {
        boss.escape_time += uint64(unpauseTime - pauseTime);
    }

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
        )
    {
        _lv = rounds[roundId_].lv;
        _prize = rounds[roundId_].prize;
        _config = rounds[roundId_].config;
        _prize_config = rounds[roundId_].prize_config;
        _prize_users = rounds[roundId_].prize_users;
    }

    function preRoundLevelOf(address user_) external view returns (uint256 _roundId, uint256 _lv) {
        _roundId = userPreRoundLevel[user_].roundId;
        _lv = userPreRoundLevel[user_].lv;
    }

    function killRewardRoundLevelsOf(
        address user
    ) external view returns (RoundLevel[] memory _lvs) {
        _lvs = killRewardRoundLevels[user];
    }

    function attackedLvsOf(
        uint256 roundId_,
        address user
    ) external view returns (uint256[] memory lvs) {
        lvs = attacked_lvs[user][roundId_];
    }

    function getUserProxyInfo(address user) public view returns(
        address proxy_address_,
        uint256 max_round_id_,
        uint256 max_lv
        ) {
        UserProxyInfo storage proxyInfo =  _userProxy[user];
        proxy_address_ = proxyInfo.proxy_address;
        max_round_id_ = proxyInfo.max_round_id;
        max_lv = proxyInfo.max_lv;
    }

    function setUserProxyAddress(address proxy_address_) external whenGameNotPaused {        
        _userProxy[msg.sender].proxy_address = proxy_address_;
    }

    function setUserProxyMaxRoundAndLevel(
        uint256 max_round_id_,
        uint256 max_lv_
        ) external whenGameNotPaused {
        _userProxy[msg.sender].max_round_id = max_round_id_;
        _userProxy[msg.sender].max_lv = max_lv_;
    }

    function _checkProxy(
        address original_user_,
        uint256 roundId_,
        uint256 lv_
        ) view internal {
        UserProxyInfo storage proxyInfo =  _userProxy[original_user_];
        require(proxyInfo.proxy_address == msg.sender, "invalid proxy");
        require(roundId_ <= proxyInfo.max_round_id, "roundId_ > max_round_id_");
        require(lv_ <= proxyInfo.max_lv, "lv_ > max_lv");
    }

    function proxyPreAttack(
        address original_user_,
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
    ) external whenGameNotPaused {
        _checkProxy(original_user_, roundId_, lv_);
        _preAttack(original_user_, roundId_, lv_, bullet_amount_);
    }

    function proxyAttack(
        address original_user_,
        uint256 roundId_,
        uint256 lv_,
        uint256 bullet_amount_
    ) external whenGameNotPaused {
        require(msg.sender.code.length == 0, "EOA only");
         _checkProxy(original_user_, roundId_, lv_);
        _attack(original_user_, roundId_, lv_, bullet_amount_);
    }

    // upgrade version vars
    struct UserProxyInfo {
        address proxy_address;
        uint256 max_round_id;
        uint256 max_lv;
    }

    mapping(address => UserProxyInfo) private _userProxy; // mapping slot : the same as uint256

    uint256[63] private __gap; // original:  uint256[64] private __gap;
}