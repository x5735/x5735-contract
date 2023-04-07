/**
 *Submitted for verification at BscScan.com on 2023-03-31
*/

// Code written by FOXCHAINDEV
// SPDX-License-Identifier: None

pragma solidity 0.8.15;

interface ICCVRF{
    function supplyRandomness(uint256 requestID, uint256[] memory randomNumbers) external;
}

contract CodeCraftrsVRF {
    address private constant CRYPT0JAN = 0xF118b279F0Fd3471666E974924dD819f606A7a9d;
    address private constant FOXCHAINDEV = 0xd1dE4abB0a3f010BBA1c9C7FC6123dfa53007048;
    address private CodeCraftrWallet = 0x9E0149DD74D2dD9c546Cf133aB0119709F8fD4ec;
    address private CodeCraftrSalary = 0xFf3B9d2B15f598D1b92A0DBc0e6c976a460CC81b;
    uint256 public nonce;

    event someoneNeedsRandomness(address whoNeedsRandomness, uint256 nonce, uint256 requestID, uint256 howManyNumbers);

    modifier onlyOwner() {require(msg.sender == FOXCHAINDEV || msg.sender == CRYPT0JAN, "Only CodeCraftrs can do that"); _;}

    constructor() {}
    receive() external payable {}
    
    function requestRandomness(uint256 requestID, uint256 howManyNumbers) external payable{
        require(msg.value >= 0.001 ether, "Randomness has a price!");
        emit someoneNeedsRandomness(msg.sender, nonce, requestID, howManyNumbers);
        nonce++;
    }

    function giveTheManHisRandomness(address theMan, uint256 requestID, uint256[] memory randomNumbers) external {
        require(msg.sender == CodeCraftrWallet, "Only one wallet has the power to do this");
        ICCVRF(theMan).supplyRandomness(requestID, randomNumbers);
    }

    function sendToSalaryWallet() external {
        payable(CodeCraftrSalary).transfer(address(this).balance);
    }
}