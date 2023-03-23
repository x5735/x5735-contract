// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVoting.sol";

contract Voting is IVoting, Ownable {
    IERC20 public weightToken;

    address public creator;
    uint256 public proposalsCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(uint256 => Vote)) public votes;
    mapping(uint256 => uint256) public votesCount;
    mapping(uint256 => mapping(address => uint256)) public voterId;
    mapping(uint256 => mapping(uint8 => uint256)) public choiceBalance;

    struct Proposal {
        uint256 id;
        string title;
        string body;
        string[] choices;
        address author;
        uint64 start;
        uint64 end;
    }

    struct Vote {
        uint256 balance;
        uint64 created;
        uint8 choice; //indexed from 1
        address voter;
    }

    event ProposalCreated(uint256 indexed id);
    event VoteSent(address indexed voter);

    constructor(IERC20 _weightToken) {
        weightToken = _weightToken;
    }

    fallback() external payable {}

    receive() external payable {}

    function createProposal(
        string memory _title,
        string memory _body,
        string[] memory _choices,
        uint64 _start,
        uint64 _end
    ) external returns (uint256 id) {
        require(
            creator == address(0) || creator == msg.sender,
            "Access denied"
        );
        require(_start < _end, "Invalid end time");
        require(_choices.length > 1, "Invalid choices size");

        proposalsCount = proposalsCount + 1;
        id = proposalsCount;

        Proposal storage proposal = proposals[id];
        proposal.id = id;
        proposal.title = _title;
        proposal.body = _body;
        proposal.choices = _choices;
        proposal.start = _start;
        proposal.end = _end;
        proposal.author = msg.sender;

        emit ProposalCreated(id);
    }

    function sendVote(uint256 _id, uint8 _choice) external {
        Proposal memory proposal = proposals[_id];
        string[] memory choices = _getChoices(_id);

        require(choices.length > 1, "Proposal not exists");
        require(
            block.timestamp >= proposal.start &&
                block.timestamp <= proposal.end,
            "Voting is over"
        );
        require(_choice > 0 && _choice <= choices.length, "Incorrect choice");

        uint256 voteId = voterId[_id][msg.sender];
        uint256 balance = weightToken.balanceOf(msg.sender);

        Vote storage vote = votes[_id][voteId];

        if (voteId == 0) {
            voteId = votesCount[_id] + 1;
            votesCount[_id] = voteId;
            voterId[_id][msg.sender] = voteId;
        } else {
            choiceBalance[_id][vote.choice] -= vote.balance;
        }

        vote = votes[_id][voteId];
        vote.balance = balance;
        vote.choice = _choice;
        vote.voter = msg.sender;
        vote.created = uint64(block.timestamp);

        choiceBalance[_id][_choice] += balance;

        emit VoteSent(msg.sender);
    }

    function getWinningChoice(
        uint256 _id
    ) external view returns (uint8 choice) {
        Proposal memory proposal = proposals[_id];
        string[] memory choices = _getChoices(_id);

        require(choices.length > 1, "Proposal not exists");
        require(block.timestamp > proposal.end, "Voting is active");

        choice = 0;

        uint256 maxBalance = 0;

        for (uint8 i = 1; i <= choices.length; i++) {
            uint256 currentBalance = choiceBalance[_id][i];

            if (currentBalance == maxBalance) {
                choice = 0;
            }

            if (currentBalance > maxBalance) {
                maxBalance = currentBalance;
                choice = i;
            }
        }
    }

    function getChoices(
        uint _id
    ) external view returns (string[] memory choices) {
        choices = _getChoices(_id);
    }

    function setCreator(address _creator) external onlyOwner {
        creator = _creator;
    }

    function _getChoices(
        uint _id
    ) internal view returns (string[] memory choices) {
        choices = proposals[_id].choices;
    }
}