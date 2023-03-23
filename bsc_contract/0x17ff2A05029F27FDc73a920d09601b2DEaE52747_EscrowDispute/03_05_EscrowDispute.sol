// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEscrowDatabase.sol";
import "./interfaces/IVoting.sol";

contract EscrowDispute is Ownable {
    IVoting private _votingContract;
    IEscrowDatabase private _databaseContract;

    struct DisputeStorage {
        uint256[] milestonesId;
        mapping(uint256 => Dispute) disputes;
    }

    struct Dispute {
        address escrowContract;
        uint256 milestoneId;
        address creator;
        bool raiseByBuyer;
        uint256 votingId;
        bool inProcess;
        uint256 refund;
        uint256 creationTime;
    }

    mapping(address => DisputeStorage) private _disputes;
    address[] private _escrowsInDispute;

    fallback() external payable {}

    receive() external payable {}

    modifier onlyEscrowContracts() {
        bool _found = false;

        for (uint256 i = 0; i < _databaseContract.getAllEscrowContracts().length; i++) {
            if (_databaseContract.getAllEscrowContracts()[i] == msg.sender) {
                _found = true;
            }
        }

        require(_found, "The call is only available from the escrow smart contract");
        _;
    }

    function setVotingContract(address _contractAddress) public onlyOwner {
        _votingContract = IVoting(_contractAddress);
    }

    function setDatabaseContract(address _contractAddress) public onlyOwner {
        _databaseContract = IEscrowDatabase(_contractAddress);
    }

    function getEscrowsInDispute() public view returns (address[] memory) {
        return _escrowsInDispute;
    }

    function getRefund(uint256 _milestoneId) public view returns(uint256) {
        return _disputes[msg.sender].disputes[_milestoneId].refund;
    }

    function getRaiseByBuyerOfDispute(uint256 _milestoneId) public view returns(bool) {
        return _disputes[msg.sender].disputes[_milestoneId].raiseByBuyer;
    }

    function getDisputeStatusByAddressAndMilestoneId(address _escrowAddress, uint256 _milestoneId) public view returns(bool) {
        return _disputes[_escrowAddress].disputes[_milestoneId].inProcess;
    }

    function getAllDisputesByAddress(address _escrowAddress) public view returns(Dispute[] memory) {
        uint256 _disputesCounter = 0;

        for (uint256 i = 0; i < _disputes[_escrowAddress].milestonesId.length; i++) {
            _disputesCounter += 1;
        }

        Dispute[] memory _returnArray = new Dispute[](_disputesCounter);

        for (uint256 i = 0; i < _disputes[_escrowAddress].milestonesId.length; i++) {
            _returnArray[i] = _disputes[_escrowAddress].disputes[_disputes[_escrowAddress].milestonesId[i]];
        }

        return _returnArray;
    }

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
    ) public onlyEscrowContracts returns (uint256) {
        require(_disputes[msg.sender].disputes[_milestoneId].votingId == 0, "Dispute for this milestone already created or has been resolved");
        
        Dispute memory dispute = Dispute(
            msg.sender,
            _milestoneId,
            _creator,
            _raiseByBuyer,
            _votingContract.createProposal(_title, _body, _choices, _start, _end),
            true,
            _refund,
            block.timestamp
        );

        _disputes[msg.sender].disputes[_milestoneId] = dispute;

        _disputes[msg.sender].milestonesId.push(_milestoneId);

        _escrowsInDispute.push(msg.sender);

        return _disputes[msg.sender].disputes[_milestoneId].votingId;
    }

    function resolveDispute(
        uint256 _milestoneId, 
        address _caller
    ) public onlyEscrowContracts returns (uint8) {
        require(_caller == _disputes[msg.sender].disputes[_milestoneId].creator, "You are not disput creator");
        require(_disputes[msg.sender].disputes[_milestoneId].inProcess, "Dispute already resolved");

        for (uint256 i = 0; i < _escrowsInDispute.length; i++) {
            if (msg.sender == _escrowsInDispute[i]) {
                _deleteteItemFromEscrowsInDispute(i);
            }
        }

        _disputes[msg.sender].disputes[_milestoneId].inProcess = false;

        return _votingContract.getWinningChoice(_disputes[msg.sender].disputes[_milestoneId].votingId);
    }

    function _deleteteItemFromEscrowsInDispute(uint256 _index) private {
        _escrowsInDispute[_index] = _escrowsInDispute[_escrowsInDispute.length - 1];
        _escrowsInDispute.pop();
    }
}