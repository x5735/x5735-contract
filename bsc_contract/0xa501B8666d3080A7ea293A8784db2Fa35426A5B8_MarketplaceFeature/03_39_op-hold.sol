// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OPV_HOLD {
    using Counters for Counters.Counter;
    Counters.Counter private index;

    struct UserHold {
        address userAddres;
        uint256 totalHold;
        bool is_winner;
    }

    mapping(address => UserHold) public listHold;
    address[] holderAddresses;

    uint256 private idOnSystem;
    uint256 public endHold;
    uint256 public publicSale;
    uint256 public totalWinner = 10;
    uint256 public minHold;
    address owner;

    IERC20 public OPV;

    event HoldToken(address user, uint256 amount);
    event WithdrawToken(address user, uint256 amount);

    constructor(
        uint256 timeEndHold,
        uint256 publicTime,
        address addressOPV,
        uint256 min
    ) {
        owner = msg.sender;
        endHold = timeEndHold;
        publicSale = publicTime;
        minHold = min;
        OPV = IERC20(addressOPV); // Change when deploy
        OPV.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    modifier onlyOwner(address sender) {
        require(sender == owner, "Is not Owner");
        _;
    }

    function holdToken(uint256 amount) public {
        require(amount >= minHold, "Min hold error");
        require(block.timestamp < endHold, "Pass time hold");
        require(OPV.balanceOf(msg.sender) > amount, "Invalid balanceOf");
        require(
            OPV.allowance(msg.sender, address(this)) > amount,
            "Invalid allowance"
        );
        OPV.transferFrom(msg.sender, address(this), amount);
        if (listHold[msg.sender].totalHold == 0) {
            holderAddresses.push(msg.sender);
        }
        listHold[msg.sender].totalHold += amount;

        emit HoldToken(msg.sender, amount);
    }

    function withdrawHold(uint256 amount) public {
        require(listHold[msg.sender].totalHold >= amount, "Invalid amount");
        require(block.timestamp > endHold, "Invalid time");

        OPV.transfer(msg.sender, amount);
        listHold[msg.sender].totalHold -= amount;
        emit WithdrawToken(msg.sender, amount);
    }

    function setTotalWinner(uint256 _total) public onlyOwner(msg.sender) {
        totalWinner = _total;
    }

    function getTotalTokenHold(address userAddress)
        public
        view
        returns (uint256)
    {
        return listHold[userAddress].totalHold;
    }

    function getTimeToPublic() public view returns (uint256) {
        return publicSale;
    }

    function setTimeToPublic(uint256 timestamp) public onlyOwner(msg.sender) {
        publicSale = timestamp;
    }

    function checkWinner(address userAddress) public view returns (bool) {
        uint256 count;
        uint256 amount = listHold[userAddress].totalHold;
        for (uint256 i = 0; i < holderAddresses.length; i++) {
            if (holderAddresses[i] != userAddress) {
                if (listHold[holderAddresses[i]].totalHold > amount && listHold[holderAddresses[i]].totalHold != 0) count++;
            }
        }
        if (block.timestamp < endHold) return false;
        if (count >= totalWinner) return false;
        return true;
    }

    function checkWinnerGetList(address userAddress) public view returns (bool) {
        uint256 count;
        uint256 amount = listHold[userAddress].totalHold;
        for (uint256 i = 0; i < holderAddresses.length; i++) {
            if (holderAddresses[i] != userAddress) {
                if (listHold[holderAddresses[i]].totalHold > amount && listHold[holderAddresses[i]].totalHold != 0) count++;
            }
        }
        if (count >= totalWinner) return false;
        return true;
    }

    function getListWinner() public view returns (address[] memory users) {
        users = new address[](totalWinner);
        uint256 _index = 0; 
        for (uint256 i =0;i < holderAddresses.length;i++){
            if (checkWinnerGetList(holderAddresses[i]) && _index < totalWinner) {
                users[_index]= holderAddresses[i];
                _index++;
            }
        }
    }
}