// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/* solhint-disable */

interface IDCBTokenClaim {
    struct Params {
        address rewardTokenAddr;
        address walletStoreAddr;
        address vestingAddr;
        bytes32 answerHash;
        address tiersAddr;
        uint256 distAmount;
        uint8 minTier;
        uint32 startDate;
        uint32 endDate;
        Tiers[] tiers;
    }

    struct Tiers {
        uint256 minLimit;
        uint16 multi;
    }

    function ANSWER_HASH() external view returns (bytes32);

    function _vesting() external view returns (address);

    function claimInfo()
        external
        view
        returns (uint8 minTier, uint32 createDate, uint32 startDate, uint32 endDate, uint256 distAmount);

    function claimTokens() external returns (bool);

    function getClaimForTier(uint8 _tier, uint8 _multi) external view returns (uint256);

    function getClaimableAmount(address _address) external view returns (uint256);

    function getParticipants() external view returns (address[] memory);

    function getRegisteredUsers() external view returns (address[] memory);

    function getTier(address _user) external view returns (uint256 _tier, uint16 _holdMulti);

    function initialize(Params memory p) external;

    function registerForAllocation(bytes memory _sig) external returns (bool);

    function tierInfo(uint256) external view returns (uint256 minLimit, uint16 multi);

    function totalShares() external view returns (uint256);

    function userAllocation(address)
        external
        view
        returns (uint256 shares, uint8 registeredTier, bool active, uint256 claimedAmount);
}