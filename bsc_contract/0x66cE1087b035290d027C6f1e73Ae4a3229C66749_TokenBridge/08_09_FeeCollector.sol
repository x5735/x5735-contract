// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/Address.sol';

contract FeeCollector is Ownable {
    using Address for address;

    mapping(string => uint256) public configureFees;
    uint256 public collectedFees;
    uint256 public withdrawnFees;

    event FeeConfigureChanged(string method, uint256 fee);
    event FeeWithdrawn(address indexed user, uint256 amount);

    function setFeesConfiguration(string[] memory methods, uint256[] memory fees) public onlyOwner {
        require(methods.length == fees.length, 'FeeCollector: invalid set of configuration provided');
        for (uint i=0; i<methods.length; i++) {
            configureFees[methods[i]] = fees[i];
            emit FeeConfigureChanged(methods[i], fees[i]);
        }
    }

    function withdrawCollectedFees(address addr, uint256 amount) public onlyOwner {
        require(addr != address(0), 'FeeCollector: address needs to be different than zero!');
        require(collectedFees >= amount, 'FeeCollector: not enough fees to withdraw!');
        collectedFees = collectedFees - amount;
        withdrawnFees = withdrawnFees + amount;
        Address.sendValue(payable(addr), amount);
        emit FeeWithdrawn(addr, amount);
    }

    modifier collectFee(string memory method) {
        require(msg.value > 0 || configureFees[method] == 0, 'FeeCollector: this method requires fee');
        require(msg.value == configureFees[method], 'FeeCollector: wrong fee amount provided');
        collectedFees = collectedFees + msg.value;
        _;
    }
}