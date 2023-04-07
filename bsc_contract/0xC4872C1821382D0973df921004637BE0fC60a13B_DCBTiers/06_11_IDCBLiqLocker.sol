// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDCBLiqLocker {
    function add(
        bool _isWithdrawLocked,
        uint128 _rewardRate,
        uint16 _lockPeriodInDays,
        uint32 _endDate,
        uint256,
        address _inputToken,
        address _rewardToken
    )
        external;

    function set(
        uint16 _pid,
        bool _isWithdrawLocked,
        uint128 _rewardRate,
        uint16 _lockPeriodInDays,
        uint32 _endDate,
        uint256,
        address,
        address _reward
    )
        external;

    function setMultiplier(
        uint16 _pid,
        string memory _name,
        address _contractAdd,
        bool _isUsed,
        uint16 _multi,
        uint128 _start,
        uint128 _end
    )
        external;

    function transferStuckToken(address _token) external returns (bool);

    function transferStuckNFT(address _nft, uint256 _id) external returns (bool);

    function addLiquidityAndLock(uint8 _pid, uint256 _token0Amt, uint256 _token1Amt) external returns (bool);

    function unlockAndRemoveLP(uint16 _pid, uint256 _amount) external returns (bool);

    function claim(uint16 _pid) external returns (bool);

    function claimAll() external returns (bool);

    function poolLength() external view returns (uint256);

    function payout(uint16 _pid, address _addr) external view returns (uint256 reward);

    function canClaim(uint16 _pid, address _addr) external view returns (bool);

    function ownsCorrectMulti(uint16 _pid, address _addr) external view returns (bool);

    function calcMultiplier(uint16 _pid, address _addr) external view returns (uint16 multi);

    function isWrappedNative(address _pair) external view returns (uint8 pos);

    function multis(uint256)
        external
        view
        returns (string memory name, address contractAdd, bool active, uint16 multi, uint128 start, uint128 end);

    function pools(uint256)
        external
        view
        returns (
            bool isWithdrawLocked,
            uint128 rewardRate,
            uint16 lockPeriodInDays,
            uint32 totalInvestors,
            uint32 startDate,
            uint32 endDate,
            uint256 totalInvested,
            uint256 hardCap,
            address input,
            address reward
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
            uint32 lastPayout,
            uint32 depositTime,
            uint256 totalClaimed
        );
}