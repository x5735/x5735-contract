// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

interface IEscrowDispute {
    function getEscrowsInDispute() external view returns (address[] memory);

    function getRefund(uint256 _milestoneId) external view returns(uint256);

    function getRaiseByBuyerOfDispute(uint256 _milestoneId) external view returns(bool);

    function getDisputeStatusByAddressAndMilestoneId(address _escrowAddress, uint256 _milestoneId) external view returns(bool);

    function raiseDispute(
        uint256 _milestoneId,
        bool _raiseByBuyer,
        address _creator,
        string memory _title,
        string memory _body,
        string[] memory _choices,
        uint64 _start,
        uint64 _end,
        uint256 _refund
    ) external returns (uint256);

    function resolveDispute(
        uint256 _milestoneId, 
        address _caller
    ) external returns (uint8);
}