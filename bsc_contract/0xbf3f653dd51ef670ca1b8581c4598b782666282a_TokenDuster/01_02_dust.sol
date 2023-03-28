// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";

contract TokenDuster {
    address public immutable tokenAddress;
    uint public  dustAmount;
    address[] public addresses;
  

    mapping(address => bool) public hasReceivedDust;

    constructor(address _tokenAddress, uint256 _newDustAmount) {
        tokenAddress = _tokenAddress;
        dustAmount = _newDustAmount;
        
    }

    function addAddresses(address[] calldata _addresses) external {
        require(addresses.length + _addresses.length <= 500, "Cannot add more than 500 addresses");
        for (uint i = 0; i < _addresses.length; i++) {
            addresses.push(_addresses[i]);
        }
    }
    function changeDustAmount(uint _newDustAmount) external {
    dustAmount = _newDustAmount;
}

    function dustToken(uint _startIndex) external {
    IERC20 token = IERC20(tokenAddress);
    uint endIndex = _startIndex + 50;
    if (endIndex > addresses.length) {
        endIndex = addresses.length;
    }
    uint balance = token.balanceOf(address(this));
    require(balance >= dustAmount * (endIndex - _startIndex), "Insufficient token balance in contract");
    for (uint i = _startIndex; i < endIndex; i++) {
        if (!hasReceivedDust[addresses[i]]) {
            hasReceivedDust[addresses[i]] = true;
            require(token.transfer(addresses[i], dustAmount), "Transfer failed");
        }
    }
}
function withdrawTokens(address _to, address _tokenAddress, uint256 _amount) external {
    require(msg.sender == _to, "Only the owner can withdraw tokens");
    IERC20 token = IERC20(_tokenAddress);
    require(token.transfer(_to, _amount), "Token transfer failed");
}
    
}