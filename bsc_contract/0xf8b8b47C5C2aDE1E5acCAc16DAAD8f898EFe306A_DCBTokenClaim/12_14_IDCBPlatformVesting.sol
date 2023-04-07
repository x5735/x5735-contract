// SPDX-License-Identifier: MIT

//** DCB Vesting Interface */

pragma solidity 0.8.19;

interface IDCBPlatformVesting {
    enum Type {
        Linear,
        Monthly,
        Interval
    }

    struct VestingInfo {
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 initialUnlockPercent;
        Type vestType;
        uint256 interval;
        uint256 unlockPerInterval;
        uint256[] timestamps;
    }

    struct VestingPool {
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 initialUnlockPercent;
        WhitelistInfo[] whitelistPool;
        mapping(address => HasWhitelist) hasWhitelist;
        Type vestType;
        uint256 interval;
        uint256 unlockPerInterval;
        uint256[] timestamps;
    }

    /**
     *
     * @dev WhiteInfo is the struct type which store whitelist information
     *
     */
    struct WhitelistInfo {
        address wallet;
        uint256 amount;
        uint256 distributedAmount;
        uint256 value; // price * amount in decimals of payment token
        uint256 joinDate;
        uint256 refundDate;
        bool refunded;
    }

    struct HasWhitelist {
        uint256 arrIdx;
        bool active;
    }

    struct ContractSetup {
        address _innovator;
        address _paymentReceiver;
        address _vestedToken;
        address _paymentToken;
        address _tiers;
        uint256 _totalTokenOnSale;
        uint256 _gracePeriod;
    }

    struct VestingSetup {
        uint256 _startTime;
        uint256 _cliff;
        uint256 _duration;
        uint256 _initialUnlockPercent;
        uint256 _interval;
        uint16 _unlockPerInterval;
        uint8 _monthGap;
        Type _type;
    }

    struct BuybackSetup {
        address router;
        address[] path;
    }

    event Claim(address indexed token, uint256 amount, uint256 time);

    event SetWhitelist(address indexed wallet, uint256 amount, uint256 value);

    event Refund(address indexed wallet, uint256 amount);

    function initializeCrowdfunding(ContractSetup memory c, VestingSetup memory p, BuybackSetup memory b) external;

    function initializeTokenClaim(address _token, VestingSetup memory p) external;

    function setCrowdfundingWhitelist(address _wallet, uint256 _amount, uint256 _value) external;

    function setTokenClaimWhitelist(address _wallet, uint256 _amount) external;

    function claimDistribution(address _wallet) external returns (bool);

    function getWhitelist(address _wallet) external view returns (WhitelistInfo memory);

    function getWhitelistPool() external view returns (WhitelistInfo[] memory);

    function transferOwnership(address _newOwner) external;

    /**
     *
     * inherit functions will be used in contract
     *
     */

    function getVestAmount(address _wallet) external view returns (uint256);

    function getReleasableAmount(address _wallet) external view returns (uint256);

    function getVestingInfo() external view returns (VestingInfo memory);
}