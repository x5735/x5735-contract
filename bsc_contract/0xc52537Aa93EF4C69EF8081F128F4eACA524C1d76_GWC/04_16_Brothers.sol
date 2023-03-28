// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Brothers is Ownable{

    using Address for address;
    bool private _addBrotherFilter = false;
    mapping(address => address) private _brothers;
    

    function _addBrother(address from, address to) internal {
        if (_addBrotherFilter || _brothers[to] != address(0) || to == owner()) {
            return;
        }
        _brothers[to] = from;
    }

    function _getBrothers(uint256 tier, address who) private view returns (address[] memory) {
        address[] memory result = new address[](tier);
        result[--tier] = _brothers[who];
        while (tier-- > 0){
            if (result[tier + 1] == address(0)) break; 
            result[tier] = _brothers[result[tier + 1]];
        }
        return result;
    }

    function _BrothersReward(uint256 tier, address from, address who, uint256 amount, function(address, address, uint256) transfer_) internal returns (uint256 remain) {
       uint256 brothersShare = amount / tier;
       address[] memory brothers = _getBrothers(tier, who);
        for (uint256 i = 0; i < brothers.length; i++) {
            if (address(0) == brothers[i] || brothers[i].isContract() || brothers[i] == from) {
                remain += brothersShare;
                continue;
            } 
            transfer_(from, brothers[i], brothersShare);
        }
    }
    
    function setAddBrotherFilter(bool addBrotherFilter) external onlyOwner{
        _addBrotherFilter = addBrotherFilter;
    }


}