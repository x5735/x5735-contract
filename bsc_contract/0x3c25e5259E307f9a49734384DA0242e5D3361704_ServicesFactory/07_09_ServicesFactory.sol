// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEscrowDatabase.sol";
import "../interfaces/IEscrowDispute.sol";
import "../escrows/ServicesEscrow.sol";
import "../EscrowDatabase.sol";

contract ServicesFactory is Ownable {
    IEscrowDatabase private _escrowDatabaseContract;
    IEscrowDispute private _escrowDisputeContract;

    fallback() external payable {}

    receive() external payable {}

    function setEscrowDatabaseContract(address _escrowDatabaseAddress) public onlyOwner {
        _escrowDatabaseContract = IEscrowDatabase(_escrowDatabaseAddress);
    }

    function setEscrowDisputeContract(address _escrowDisputeAddress) public onlyOwner {
        _escrowDisputeContract = IEscrowDispute(_escrowDisputeAddress);
    }

    function createServicesEscrow(
        address _seller,
        address _buyer,
        address _coinAddress,
        uint256 _deadlineTime,
        string memory _title,
        string memory _itemName,
        string memory _itemDescription,
        string memory _itemCategory,
        bool _feePaidByBuyer,
        ServicesEscrow.Milestone[] memory _milestones
    ) public returns (address) {
        bool _approvedBySeller = false;
        bool _approvedByBuyer = false;

        if (msg.sender == _seller) {
            _approvedBySeller = true;
        } else if (msg.sender == _buyer) {
            _approvedByBuyer = true;
        } else {
            require(true == false, "You are neither a seller not a buyer");
        }

        _escrowDatabaseContract.increaseEscrowCounter();

        ServicesEscrow.Escrow memory _escrow = ServicesEscrow.Escrow(
            _escrowDatabaseContract.escrowCounter(),
            "Services",
            _seller,
            _buyer,
            _coinAddress,
            _approvedBySeller,
            _approvedByBuyer,
            !_approvedByBuyer,
            block.timestamp,
            _deadlineTime,
            _title,
            _itemName,
            _itemDescription,
            _itemCategory,
            _feePaidByBuyer
        );

       ServicesEscrow _newServicesEscrow = new ServicesEscrow(
            msg.sender, 
            _escrow, 
            _milestones, 
            address(_escrowDatabaseContract),
            address(_escrowDisputeContract)
       );

       _escrowDatabaseContract.addAllEscrowContracts(address(_newServicesEscrow));

       _escrowDatabaseContract.addServicesEscrowContracts(address(_newServicesEscrow));

       _escrowDatabaseContract.addEscrowsOfUser(msg.sender, address(_newServicesEscrow));

       return address(_newServicesEscrow);
    }
}