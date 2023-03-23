// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

interface IVoting {
    function getWinningChoice(
        uint256 proposalId
    ) external view returns (uint8 choice);

    function createProposal(
        string memory title,
        string memory body,
        string[] memory choices,
        uint64 start,
        uint64 end
    ) external returns (uint256 id);

    function sendVote(uint256 proposalId, uint8 choice) external;
}