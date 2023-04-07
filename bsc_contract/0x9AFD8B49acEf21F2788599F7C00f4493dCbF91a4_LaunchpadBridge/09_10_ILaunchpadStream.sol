// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

interface ILaunchpadStream {

    struct UserInfo {
        uint256 baseAmount;
        uint256 pairAmount;
        uint256 mintAmount;
        uint256 lockedSince;
        uint256 lockedUntil;
        uint256 releaseTimestamp;
        uint256 releaseTimerange;
        bool isLocked;
    }
    
    function userInfo(address addr) external view returns (UserInfo memory);

    function depositFor(address addr, uint256 baseAmount, uint256 pairAmount, uint256 timestamp, uint256 timerangeReward) external;
}