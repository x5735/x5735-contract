// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IMasterChef {
    function pendingShare(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
    function deposit(uint256 _pid, uint256 _amount, address _to) external;
    function harvest(uint256 _pid, address _to) external;
    function poolLength() external view returns (uint256);
    function poolInfo(uint256 _pid) external view returns (address, uint32, uint8, uint256, uint256, uint256, uint256, uint256, address, uint32, uint32, uint32);
    function withdraw(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount, address _to) external;
    function stakeAndUnstakeMagicats(uint _pid, uint[] memory stakeTokenIDs, uint[] memory unstakeTokenIDs) external;
    function getStakedMagicats(uint _pid, address _user) external view returns (uint[] memory);
    function withdrawAndHarvest(uint256 _pid, uint256 _amount, address _to) external;

    function withdrawAndHarvestShort(uint256 _pid, uint128 _amount) external;
    function harvestShort(uint256 _pid) external;
    function depositShort(uint256 _pid, uint128 _amount) external;
    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256, uint256);

    function emergencyWithdraw(uint256 _pid) external;
    function withdrawAll(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid, address _to) external;
}