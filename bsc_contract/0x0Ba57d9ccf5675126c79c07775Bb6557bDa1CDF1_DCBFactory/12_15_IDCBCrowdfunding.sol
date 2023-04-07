// SPDX-License-Identifier: MIT

//** DCB Crowdfunding Interface */
//** Author: Aceson & Aaron 2023.3 */

pragma solidity 0.8.19;

interface IDCBCrowdfunding {
    struct Params {
        address walletStoreAddr;
        address investmentAddr;
        address tiersAddr;
        address vestingAddr;
        uint256 totalTokenOnSale;
        uint256 hardcap;
        uint256 startDate;
        uint8 minTier;
        address paymentToken;
        address saleTokenAddr;
    }

    /**
     *
     * @dev this event will call when new agreement generated.
     * this is called when innovator create a new agreement but for now,
     * it is calling when owner create new agreement
     *
     */
    event CreateAgreement(Params);

    /**
     *
     * @dev it is calling when new investor joinning to the existing agreement
     *
     */
    event NewInvestment(address wallet, uint256 amount);

    /**
     *
     * inherit functions will be used in contract
     *
     */

    function registerForAllocation(bytes memory _sig) external returns (bool);

    function initialize(Params memory p) external;

    function acceptTerms(bytes memory _sign) external returns (bool);

    function fundAgreement(uint256 _investFund) external returns (bool);

    function userInvestment(address _address) external view returns (uint256 investAmount, uint256 joinDate);

    function getInfo() external view returns (uint256, uint256, uint256, uint256, uint256, uint256);

    function getParticipants() external view returns (address[] memory);

    function getUserAllocation(address _address) external view returns (uint256);
}