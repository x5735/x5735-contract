// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IEscrowDatabase.sol";
import "../interfaces/IEscrowDispute.sol";

contract ServicesEscrow {
    using SafeMath for uint256;

    IEscrowDatabase private _escrowDatabaseContract;
    IEscrowDispute private _escrowDisputeContract;

    struct Escrow {
        uint256 id;
        string escrowType;
        address seller;
        address buyer;
        address coinAddress;
        bool approvedBySeller;
        bool approvedByBuyer;
        bool active;
        uint256 creationTime;
        uint256 deadlineTime;
        string title;
        string itemName;
        string itemDescription;
        string itemCategory;
        bool feePaidByBuyer;
    }

    struct Milestone {
        string description;
        uint256 price;
        string fileUrl;
        bool completed;
    }

    address public owner;
    IERC20 private _coin;
    uint256 public platformFee = 3; // %
    address feeRecipient = 0x6501644989e8029892792ebeE2DdF276b2A112FD;
    Escrow private _escrow;
    Milestone[] private _milestones;

    constructor(
        address _creator, 
        Escrow memory _createdEscrow, 
        Milestone[] memory _createdMilestones,
        address _escrowDatabaseAddress,
        address _escrowDisputeAddress
    ) {
        owner = _creator;

        _escrowDatabaseContract = IEscrowDatabase(_escrowDatabaseAddress);
        _escrowDisputeContract = IEscrowDispute(_escrowDisputeAddress);

        _escrow = _createdEscrow;

        for (uint256 i = 0; i < _createdMilestones.length; i++) {
            Milestone memory _milestone = Milestone(
                _createdMilestones[i].description,
                _createdMilestones[i].price,
                '',
                false
            );

            _milestones.push(_milestone);
        }

        _coin = IERC20(_createdEscrow.coinAddress);
    }

    fallback() external payable {}

    receive() external payable {}

    modifier isActive() {
        require(_escrow.active == true, "Escrow is not active");
        _;
    }

    modifier onlyForBuyerAndSeller() {
        require(msg.sender == _escrow.buyer || msg.sender == _escrow.seller, "You are neither a seller not a buyer");
        _;
    }
    
    modifier notDisputed(uint256 _milestoneId) {
        bool disputeStatus = _escrowDisputeContract.getDisputeStatusByAddressAndMilestoneId(address(this), _milestoneId);

        require(!disputeStatus, "Milestone in dispute status");
        _;
    }

    function getEscrow() public onlyForBuyerAndSeller view returns (Escrow memory) {
        return _escrow;
    }

    function getMilestones() public onlyForBuyerAndSeller view returns (Milestone[] memory) {
        return _milestones;
    }

    function withdrawFundsFromBuyer() public {
        require(msg.sender == _escrow.buyer, "Not an escrow buyer");

        if (!_escrow.active) {
            _escrow.active = true;
        }

        uint256 _totalFee = 0;

        for (uint256 i = 0; i < _milestones.length; i++) {
            _totalFee = _totalFee.add(_milestones[i].price);
        }

        uint256 _platformFeeAmount = (_totalFee.mul(platformFee)).div(100);

        if (_escrow.feePaidByBuyer) {
            _totalFee = _totalFee.add(_platformFeeAmount);
        }

        _coin.transferFrom(_escrow.buyer, address(this), _totalFee); // Taking money into Escrow with platform fee

        if (_escrow.feePaidByBuyer) {
            _coin.transfer(feeRecipient, _platformFeeAmount); // Transfer fee to Fee Recipient
        }
    }

    function approveEscrow(bool _approvedFromBuyer) public isActive {
        if (_approvedFromBuyer) {
            require(_escrow.buyer == msg.sender, "Not an escrow buyer");
            require(_escrow.approvedByBuyer == false , "Already approved by buyer");

            withdrawFundsFromBuyer();

            _escrow.approvedByBuyer = true;
        } else {
            require(_escrow.seller == msg.sender, "Not an escrow seller");
            require(_escrow.approvedBySeller == false , "Already approved by seller");

            _escrow.approvedBySeller = true;
        }

        _escrowDatabaseContract.addEscrowsOfUser(msg.sender, address(this));

        _escrow.deadlineTime = block.timestamp + _escrow.deadlineTime;
    }

    function sellerReleaseMilestone(
        uint256 _milestoneId, 
        string memory _ipfsUrl
    ) public isActive notDisputed(_milestoneId) returns (Milestone memory) {
        require(msg.sender == _escrow.seller, "Not an escrow seller");
        require(_milestoneId >= 0 && _milestoneId < _milestones.length, "Undefined milstone id");
        require(_escrow.approvedByBuyer, "Escrow not approved by buyer");
        require(_escrow.approvedBySeller, "Escrow not approved by seller");
        require(!_milestones[_milestoneId].completed, "Milestone is completed");

        _milestones[_milestoneId].fileUrl = _ipfsUrl;

        return _milestones[_milestoneId];
    }

    function buyerApproveMilestone(uint256 _milestoneId) public isActive notDisputed(_milestoneId) returns (Milestone memory) {
        require(_escrow.buyer == msg.sender, "Not a buyer of this escrow");
        require(_milestoneId >= 0 && _milestoneId < _milestones.length, "Undefined milstone id");
        require(_escrow.approvedByBuyer, "Escrow not approved by buyer");
        require(_escrow.approvedBySeller, "Escrow not approved by seller");
        require(!_milestones[_milestoneId].completed, "Milestone already approved");

        _milestones[_milestoneId].completed = true;

        uint256 _amountToSeller = _milestones[_milestoneId].price;
        uint256 _platformFee = 0;

        if (!_escrow.feePaidByBuyer) {
            _platformFee = (_amountToSeller.mul(platformFee)).div(100);

            _amountToSeller = _amountToSeller.sub(_platformFee);
        }

        _coin.transfer(_escrow.seller, _amountToSeller); // Giving milestone money to seller

        if (!_escrow.feePaidByBuyer) {
            _coin.transfer(feeRecipient, _platformFee); // Transfer fee to fee recipient
        }

        return _milestones[_milestoneId];
    }

    function raiseDispute(
        uint256 _milestoneId,
        string memory _title,
        string memory _body,
        string[] memory _choices,
        uint64 _start,
        uint64 _end,
        uint256 _refund
    ) public onlyForBuyerAndSeller returns (uint256) {
        require(_testStringForValue(_milestones[_milestoneId].fileUrl), "Milestone was not published by seller");

        bool _raiseByBuyer;

        if (msg.sender == _escrow.buyer) {
            _raiseByBuyer = true;
        } else {
            _raiseByBuyer = false;
        }

        return _escrowDisputeContract.raiseDispute(
            _milestoneId,
            _raiseByBuyer,
            msg.sender,
            _title,
            _body,
            _choices,
            _start,
            _end,
            _refund
        );
    }

    function resolveDispute(uint256 _milestoneId) public returns (bool) {
        uint8 _disputeWinningChoice = _escrowDisputeContract.resolveDispute(_milestoneId, msg.sender);

        if (_disputeWinningChoice == 1) {
            uint256 _amount = (_milestones[_milestoneId].price * _escrowDisputeContract.getRefund(_milestoneId)).div(100);

            _milestones[_milestoneId].price = (_milestones[_milestoneId].price).sub(_amount);

            bool _disputedByBuyer = _escrowDisputeContract.getRaiseByBuyerOfDispute(_milestoneId);

            if (_disputedByBuyer) {
                _coin.transfer(_escrow.buyer, _amount);
            } else {
                _coin.transfer(_escrow.seller, _amount);
                _coin.transfer(_escrow.buyer, _milestones[_milestoneId].price);

                _milestones[_milestoneId].price = 0;
            }

            return true;
        } else {
            return false;
        }
    }

    function cancelEscrow() public isActive {
        require(msg.sender == owner, "You are not the escrow owner");

        bool _callerIsBuyer;

        if (msg.sender == _escrow.buyer) {
            _callerIsBuyer = true;
        } else {
            _callerIsBuyer = false;
        }

        if (_callerIsBuyer) {
            require(!_escrow.approvedBySeller, "Seller approved escrow");

            uint256 _milestonesCoinSum;

            for (uint256 i = 0; i < _milestones.length; i++) {
                _milestonesCoinSum = _milestonesCoinSum.add(_milestones[i].price);
            }

            _coin.transfer(_escrow.buyer, _milestonesCoinSum);
        } else {
            require(!_escrow.approvedByBuyer, "Buyer approved escrow");
        }

        _escrow = Escrow(
            _escrow.id,
            "",
            address(0),
            address(0),
            address(0),
            false,
            false,
            false,
            0,
            0,
            "",
            "",
            "",
            "",
            false
        );

        _escrowDatabaseContract.deleteFromEscrowsOfUser(msg.sender, address(this));
    }

    function _testStringForValue(string memory _string) private pure returns(bool) {
        bytes memory _stringInBytes = bytes(_string);

        if (_stringInBytes.length != 0) {
            return true;
        } else {
            return false;
        }
    }
}