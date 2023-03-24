// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 < 0.9.0;

import "./ReentrancyGuardUpgradeable.sol";
import "./Math.sol";
import "./SafeMath.sol";
import "./SafeERC20Upgradeable.sol";
import "./IERC20Upgradeable.sol";
import "./ERC721Enumerable.sol";
import "./IERC721.sol";
import "./GovernanceUpgradeable.sol";

// NFT
import "./InterfaceNFT.sol";
import "./InterfaceFactory.sol";


contract GeneralNFTReward is GovernanceUpgradeable, ReentrancyGuardUpgradeable {


    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    event StakedGEGO(address indexed user, uint256 amount);
    event WithdrawnGego(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardLockedUp(address indexed user, uint256 reward);
        event NFTReceived(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    );
    event RewardTokenChanged(address oldToken, address newToken);
    event NFTTokenChanged(address oldToken, address newToken);
    event FactoryContractChanged(address oldContract, address newContract);

    IERC20Upgradeable public _rewardERC20;
    InterfaceFactory public _gegoFactory;
    InterfaceNFT public _gegoToken;
    address public _playerBook;

    address public _teamWallet;
    address public _rewardPool;
    uint256 public _startTime;

    uint256 public _maxStakedDego;

    uint256 public constant DURATION = 30 days;
    uint256 public constant _fixRateBase = 100000;
    uint256 public _harvestInterval;
    uint256 public _rewardPerTokenStored;
    uint256 public _periodFinish;
    uint256 public _lastUpdateTime;
    uint256 public _rewardRate;
    uint256 public totalLockedUpRewards;

    uint256 public _teamRewardRate;
    uint256 public _poolRewardRate;
    uint256 public _baseRate;
    uint256 public _punishTime;

    uint256 public _totalBalance;
    mapping(address => uint256) public _degoBalances;

    uint256 public _totalWeight;
    mapping(address => uint256) public _weightBalances;
    mapping(uint256 => uint256) public _stakeWeightes;
    mapping(uint256 => uint256) public _stakeBalances;

    mapping(address => uint256[]) public _playerGego;
    mapping(uint256 => uint256) public _gegoMapIndex;

    mapping(address => uint256) public _userRewardPerTokenPaid;
    mapping(address => uint256) public _rewards;
    mapping(address => uint256) public _lastStakedTime;
    mapping(address => uint256) public _nextHarvestUntil;
    mapping(address => uint256) public _rewardLockedUp;

    modifier updateReward(address account) {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
        _;
    }
    modifier checkStart() {
        require(block.timestamp > _startTime, "not start");
        _;
    }



    function initialize(
        address gegoNFT,
        address gegoFactory,
        address rewardAddress,
        uint256 startTime
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        _rewardERC20 = IERC20Upgradeable(rewardAddress);
        _gegoToken = InterfaceNFT(gegoNFT);
        _gegoFactory = InterfaceFactory(gegoFactory);
        _startTime = startTime;
        _lastUpdateTime = _startTime;
        _teamWallet = 0x36926c0EAbD171d67Ae19894BA9014b105243d7E;
        _rewardPool = 0x36926c0EAbD171d67Ae19894BA9014b105243d7E;
        _harvestInterval = 10;
        _teamRewardRate = 200;
        _poolRewardRate = 200;
        _baseRate = 10000;
        _punishTime = 3 days;
        _maxStakedDego = 1000000 * 1e18;
    }

    function notifyReward(uint256 reward) external onlyGovernance updateReward(address(0)) {
         uint256 balanceBefore = _rewardERC20.balanceOf(address(this));
        IERC20Upgradeable(_rewardERC20).transferFrom(_msgSender(), address(this), reward);
        uint256 balanceEnd = _rewardERC20.balanceOf(address(this));

        uint256 realReward = balanceEnd.sub(balanceBefore);

        if(block.timestamp >= _periodFinish) {
            _rewardRate = realReward.div(DURATION);
        } else {
            uint256 remaining = _periodFinish.sub(block.timestamp);
            uint256 leftOver = remaining.mul(_rewardRate);
            _rewardRate = realReward.add(leftOver).div(DURATION);
        }
        _lastUpdateTime = block.timestamp;
        _periodFinish = block.timestamp.add(DURATION);
    }
    function changeNftToken(InterfaceNFT _newContract) public onlyGovernance {
        emit NFTTokenChanged(address(_gegoToken), address(_newContract));
        _gegoToken = _newContract;
    }
    function changeFactory(InterfaceFactory _newFactory) public onlyGovernance {
        emit FactoryContractChanged(address(_gegoFactory), address(_newFactory));
        _gegoFactory = _newFactory;
    }
    function setGegoToken(address token) external onlyGovernance  {
        _gegoToken = InterfaceNFT(token);
    }
    function setGegoFactory(address factory) external onlyGovernance  {
        _gegoFactory = InterfaceFactory(factory);
    }
    function setTeamRewardRate(uint256 teamRewardRate) public onlyGovernance {
        _teamRewardRate = teamRewardRate;
    }

    function setPoolRewardRate(uint256 poolRewardRate) public onlyGovernance {
        _poolRewardRate = poolRewardRate;
    }

    function setHarvestInterval(uint256 harvestInterval) public onlyGovernance {
        _harvestInterval = harvestInterval;
    }

    function changeRewardToken(IERC20Upgradeable _newToken) public onlyGovernance {
        emit RewardTokenChanged(address(_rewardERC20), address(_newToken));
        _rewardERC20 = _newToken;
    }
    function setRewardPool(address rewardPool) public onlyGovernance {
        _rewardPool = rewardPool;
    }

    function setTeamWallet(address teamwallet) public onlyGovernance {
        _teamWallet = teamwallet;
    }


    function setWithDrawPunishTime(uint256 punishTime) public onlyGovernance {
        _punishTime = punishTime;
    }
    function change_rewardERC20(IERC20Upgradeable _newToken) public onlyGovernance {
        _rewardERC20 = _newToken;
    }

    function resetGovernance() public {
        _transferOwnership(0x36926c0EAbD171d67Ae19894BA9014b105243d7E);
    }
    function balanceOf(address account) public view  returns (uint256) {
        return _weightBalances[account];
    }
    function totalSupply() public view  returns (uint256) {
        return _totalWeight;
    }
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, _periodFinish);
    }
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return _rewardPerTokenStored;
        }
        return
        _rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(_lastUpdateTime)
            .mul(_rewardRate)
            .mul(1e18)
            .div(totalSupply())
        );
    }
    function earned(address account) public view returns (uint256) {
        return
        balanceOf(account)
        .mul(rewardPerToken().sub(_userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(_rewards[account]);
    }

    function canHarvest(address account) public view returns (bool) {
        return block.timestamp >= _nextHarvestUntil[account];
    }
        // stake NFT
    function stake(uint256 gegoId) public checkStart nonReentrant {
        _stake(gegoId);
    }
    function _stake(uint256 gegoId) private updateReward(msg.sender)  {
        uint256[] storage gegoIds = _playerGego[msg.sender];

        if (gegoIds.length == 0) {
            gegoIds.push(0);
            _gegoMapIndex[0] = 0;
        }

        gegoIds.push(gegoId);
        _gegoMapIndex[gegoId] = gegoIds.length - 1;

        _startTime = block.timestamp;

        uint256 stakeRate;
        uint256 degoAmount;
        (stakeRate, degoAmount) = getStakeInfo(gegoId);

        uint256 stakedDegoAmount = _degoBalances[msg.sender];
        uint256 stakingDegoAmount = stakedDegoAmount.add(degoAmount) <= _maxStakedDego ? degoAmount : _maxStakedDego.sub(stakedDegoAmount);

        if(stakingDegoAmount > 0) {
            uint256 stakeWeight = stakeRate.mul(stakingDegoAmount).div(_fixRateBase);
            _degoBalances[msg.sender] = _degoBalances[msg.sender].add(stakingDegoAmount);
            _weightBalances[msg.sender] = _weightBalances[msg.sender].add(stakeWeight);

            _stakeBalances[gegoId] = stakingDegoAmount;
            _stakeWeightes[gegoId] = stakeWeight;

            _totalBalance = _totalBalance.add(stakingDegoAmount);
            _totalWeight = _totalWeight.add(stakeWeight);
        }

        _gegoToken.safeTransferFrom(msg.sender, address(this), gegoId);

        if (_nextHarvestUntil[msg.sender] == 0) {
            _nextHarvestUntil[msg.sender] = block.timestamp.add(
                _harvestInterval
            );
        }
        _lastStakedTime[msg.sender] = block.timestamp;
        emit StakedGEGO(msg.sender, gegoId);
    }
    function unstake(uint256 gegoId) public checkStart nonReentrant {
        _unstake(gegoId);
    }
    function _unstake(uint256 gegoId) private updateReward(msg.sender)  {
        require(gegoId > 0, "the gegoId error");


        uint256[] memory gegoIds = _playerGego[msg.sender];
        uint256 gegoIndex = _gegoMapIndex[gegoId];

        require(gegoIds[gegoIndex] == gegoId, "not gegoId owner");

         uint256 gegoArrayLength = gegoIds.length - 1;
        uint256 tailId = gegoIds[gegoArrayLength];

        _playerGego[msg.sender][gegoIndex] = tailId;
        _playerGego[msg.sender][gegoArrayLength] = 0;

        _playerGego[msg.sender].pop();

        _gegoMapIndex[tailId] = gegoIndex;
        _gegoMapIndex[gegoId] = 0;
        
        uint256 stakeWeight = _stakeWeightes[gegoId];
        _weightBalances[msg.sender] = _weightBalances[msg.sender].sub(
            stakeWeight
        );
        _totalWeight = _totalWeight.sub(stakeWeight);

        uint256 stakeBalance = _stakeBalances[gegoId];
        _degoBalances[msg.sender] = _degoBalances[msg.sender].sub(stakeBalance);
        _totalBalance = _totalBalance.sub(stakeBalance);


        _stakeBalances[gegoId] = 0;
        _stakeWeightes[gegoId] = 0;

        _gegoToken.safeTransferFrom(address(this), msg.sender, gegoId);

        emit WithdrawnGego(msg.sender, gegoId);
    }

    // Deposita todas as NFTs do _msgSender()
    function depositAll() public checkStart nonReentrant  {
        uint256[] memory nfts = _gegoToken.tokensOfOwner(_msgSender());
        for(uint256 index = 0; index < nfts.length; index++) {
            require(nfts[index] > 0, "You don't have NFTS");
            _stake(nfts[index]);
        }
    }

    function withdraw() public checkStart nonReentrant {
        uint256[] memory gegoId = _playerGego[msg.sender];
        for (uint8 index = 1; index < gegoId.length; index++) {
            if (gegoId[index] > 0) {
                _unstake(gegoId[index]);
            }
        }
    }
    function exit() external {
        withdraw();
        harvest();
    }
    function harvest() public updateReward(msg.sender) checkStart nonReentrant {
        uint256 reward = earned(msg.sender);
        if (canHarvest(msg.sender)) {
            if (reward > 0 || _rewardLockedUp[msg.sender] > 0) {
                _rewards[msg.sender] = 0;
                reward = reward.add(_rewardLockedUp[msg.sender]);

                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(
                    _rewardLockedUp[msg.sender]
                );
                _rewardLockedUp[msg.sender] = 0;
                _nextHarvestUntil[msg.sender] = block.timestamp.add(
                    _harvestInterval
                );

                // reward for team
                uint256 teamReward = reward.mul(_teamRewardRate).div(_baseRate);
                if (teamReward > 0) {
                    _rewardERC20.safeTransfer(_teamWallet, teamReward);
                }
                uint256 leftReward = reward.sub(teamReward);
                uint256 poolReward = 0;

                //withdraw time check

                if (
                    block.timestamp <
                    (_lastStakedTime[msg.sender] + _punishTime)
                ) {
                    poolReward = leftReward.mul(_poolRewardRate).div(_baseRate);
                }
                if (poolReward > 0) {
                    _rewardERC20.safeTransfer(_rewardPool, poolReward);
                    leftReward = leftReward.sub(poolReward);
                }

                if (leftReward > 0) {
                    _rewardERC20.safeTransfer(msg.sender, leftReward);
                }

                emit RewardPaid(msg.sender, leftReward);
            }
        } else if (reward > 0) {
            _rewards[msg.sender] = 0;
            _rewardLockedUp[msg.sender] = _rewardLockedUp[msg.sender].add(
                reward
            );
            totalLockedUpRewards = totalLockedUpRewards.add(reward);
            emit RewardLockedUp(msg.sender, reward);
        }
    }

    function getPlayerIds(address account)
    public
    view
    returns (uint256[] memory gegoId)
    {
        gegoId = _playerGego[account];
    }


    function getStakeInfo(uint256 gegoId)
    public
    view
    returns (uint256 stakeRate, uint256 degoAmount)
    {
        uint256 grade;
        uint256 quality;

        (
        grade,
        quality,
        degoAmount
        ) = _gegoFactory.getAmount(gegoId);


        require(degoAmount > 0, "the gego not dego");

        stakeRate = getFixRate(grade, quality);
    }

    function getFixRate(uint256 grade, uint256 quality)
    public
    pure
    returns (uint256)
    {
        require(grade > 0 && grade < 10, "the gego not dego.");
        quality = correctQuality(grade, quality);
        uint256 unfold = 0;

        if (grade == 1) {
            unfold = (quality * 10000) / 5000;
            return unfold.add(110000);
        } else if (grade == 2) {
            unfold = (quality.sub(5000) * 10000) / 3000;
            return unfold.add(120000);
        } else if (grade == 3) {
            unfold = (quality.sub(8000) * 10000) / 1000;
            return unfold.add(130000);
        } else if (grade == 4) {
            unfold = (quality.sub(9000) * 20000) / 800;
            return unfold.add(140000);
        } else if (grade == 5) {
            unfold = (quality.sub(9800) * 20000) / 180;
            return unfold.add(160000);
        } else {
            unfold = (quality.sub(9980) * 20000) / 20;
            return unfold.add(180000);
        }
    }

    function correctQuality(uint256 grade, uint256 quality)
    public
    pure
    returns (uint256)
    {
        if (grade == 1 && quality > 5000) {
            return 5000;
        } else if (grade == 2 && quality > 8000) {
            return 8000;
        } else if (grade == 3 && quality > 9000) {
            return 9000;
        } else if (grade == 4 && quality > 9800) {
            return 9500;
        }else if (grade == 5 && quality > 9980) {
            return 9970;
        }else if (grade == 6 && quality > 10000) {
            return 9980;
        }
        return quality;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFTReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }




    
}
