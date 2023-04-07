// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDCBStaking {
    struct NFTMultiplier {
        bool active;
        string name;
        address contractAdd;
        uint16 multiplier;
        uint16 startIdx;
        uint16 endIdx;
    }

    struct PoolToken {
        address addr;
        address router;
    }

    struct Pool {
        uint256 apy;
        uint256 lockPeriodInDays;
        uint256 totalDeposit;
        uint256 hardCap;
        uint256 endDate;
        PoolToken inputToken;
        PoolToken rewardToken;
        uint256 ratio;
        address tradesAgainst;
        uint32 lastUpdatedTime;
        bool isRewardAboveInput;
    }

    function add(
        uint256 _apy,
        uint256 _lockPeriodInDays,
        uint256 _endDate,
        address _tradesAgainst,
        PoolToken memory _inputToken,
        PoolToken memory _rewardToken,
        uint256 _hardCap
    )
        external;

    function set(
        uint256 _pid,
        uint256 _apy,
        uint256 _lockPeriodInDays,
        uint256 _endDate,
        address _tradesAgainst,
        uint256 _hardCap
    )
        external;

    function setTokens(
        uint256 _pid,
        PoolToken memory _inputToken,
        PoolToken memory _rewardToken,
        uint256 _maxTransferInput,
        uint256 _maxTransferReward
    )
        external;

    function setNFT(
        uint256 _pid,
        string calldata _name,
        address _contractAdd,
        bool _isUsed,
        uint16 _multiplier,
        uint16 _startIdx,
        uint16 _endIdx
    )
        external;

    function stake(uint256 _pid, uint256 _amount) external returns (bool);

    function unStake(uint256 _pid, uint256 _amount) external returns (bool);

    function updateFeeValues(uint8 _feePercent, address _feeWallet) external;

    function updateTimeGap(uint32 newValue) external;

    function claim(uint256 _pid) external returns (bool);

    function claimAll() external returns (bool);

    function updateRatio(uint256 _pid) external returns (bool);

    function updateRatioAll() external returns (bool);

    function poolInfo(uint256)
        external
        view
        returns (
            uint256 apy,
            uint256 lockPeriodInDays,
            uint256 totalDeposit,
            uint256 hardCap,
            uint256 endDate,
            PoolToken memory inputToken,
            PoolToken memory rewardToken,
            uint256 ratio,
            address tradesAgainst,
            uint32 lastUpdatedTime,
            bool isRewardAboveInput
        );

    function users(
        uint256,
        address
    )
        external
        view
        returns (
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 lastPayout,
            uint256 depositTime,
            uint256 totalClaimed
        );

    function canUnstake(uint256 _pid, address _addr) external view returns (bool);

    function calcMultiplier(uint256 _pid, address _addr) external view returns (uint16 multi);

    function poolLength() external view returns (uint256);

    function payout(uint256 _pid, address _addr) external view returns (uint256 value);
}