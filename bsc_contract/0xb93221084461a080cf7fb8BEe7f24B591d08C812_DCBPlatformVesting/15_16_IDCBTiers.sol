// SPDX-License-Identifier: UNLICENSED

//** DCB Crowdfunding Interface */
//** Author Aaron & Aceson : DCB 2023.2 */

pragma solidity 0.8.19;

interface IDCBTiers {
    /**
     *
     * @dev Tier struct
     *
     * @param {minLimit} Minimum amount of dcb to be staked to join tier
     * @param {maxLimit} Maximum amount of dcb to be staked to join tier
     *
     */
    struct Tier {
        uint256 minLimit;
        uint256 maxLimit;
        uint256 refundFee;
    }

    function tierInfo(uint256 idx) external returns (uint256, uint256, uint256);

    function getTierOfUser(address addr) external view returns (bool flag, uint256 pos, uint256 multiplier);
}