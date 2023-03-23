// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEscrowDatabase.sol";
import "../interfaces/IEscrowDispute.sol";
import "../escrows/GoodsEscrow.sol";
import "../EscrowDatabase.sol";

contract GoodsFactory is Ownable {
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

    function createGoodsEscrow(
        address _seller,
        address _buyer,
        address _coinAddress,
        uint256 _deadlineTime,
        string memory _title,
        string memory _itemName,
        string memory _itemDescription,
        string memory _itemCategory,
        bool _feePaidByBuyer,
        GoodsEscrow.Milestone[] memory _milestones
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

        GoodsEscrow.Escrow memory _escrow = GoodsEscrow.Escrow(
            _escrowDatabaseContract.escrowCounter(),
            "Goods",
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

       GoodsEscrow _newGoodsEscrow = new GoodsEscrow(
            msg.sender, 
            _escrow, 
            _milestones, 
            address(_escrowDatabaseContract),
            address(_escrowDisputeContract)
       );

       _escrowDatabaseContract.addAllEscrowContracts(address(_newGoodsEscrow));

       _escrowDatabaseContract.addGoodsEscrowContracts(address(_newGoodsEscrow));

       _escrowDatabaseContract.addEscrowsOfUser(msg.sender, address(_newGoodsEscrow));

       return address(_newGoodsEscrow);
    }
}