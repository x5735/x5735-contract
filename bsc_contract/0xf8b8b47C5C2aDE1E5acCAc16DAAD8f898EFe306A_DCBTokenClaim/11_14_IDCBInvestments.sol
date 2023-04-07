// SPDX-License-Identifier: UNLICENSED

//** DCB Investments Interface */
//** Author Aaron & Aceson : DCB 2023.2 */

pragma solidity 0.8.19;

interface IDCBInvestments {
    function addEvent(
        address _address,
        string memory name,
        uint256 tokenPrice,
        string memory tokenSymbol,
        address vestingAddress,
        bool vestingActive,
        bool isAirdrop
    )
        external
        returns (bool);

    function claimDistribution(address _crowdfunding) external returns (bool);

    function setEvent(
        address _address,
        string memory name,
        uint256 tokenPrice,
        string memory tokenSymbol,
        address vestingAddress,
        bool vestingActive,
        bool isAirdrop
    )
        external
        returns (bool);

    function setUserInvestment(address _address, address _crowdfunding, uint256 _amount) external returns (bool);

    function getInvestmentInfo(
        address _account,
        address _crowdfunding
    )
        external
        view
        returns (
            string memory name,
            uint256 invested,
            uint256 tokenPrice,
            string memory tokenSymbol,
            bool vestingActive,
            bool isAirdrop
        );

    function getVestingInfo(
        address _account,
        address _crowdfunding
    )
        external
        view
        returns (
            uint256 startDate,
            uint256 cliff,
            uint256 duration,
            uint256 total,
            uint256 released,
            uint256 available,
            uint256 initialUnlockPercent
        );

    function getUserInvestments(address _address) external view returns (address[] memory addresses);
}