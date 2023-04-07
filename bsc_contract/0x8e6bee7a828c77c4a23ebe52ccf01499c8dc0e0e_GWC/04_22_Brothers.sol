// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Brothers is AccessControl{

    using Address for address;
    bytes32 public constant FILTER_ROLE = keccak256("FILTER_ROLE");
    bool private _addBrotherFilter = false;
    address owner;
    mapping(address => address) private _brothers;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FILTER_ROLE, _msgSender());
        _setRoleAdmin(FILTER_ROLE, DEFAULT_ADMIN_ROLE);
        owner = _msgSender();
    }

    function _addBrother(address from, address to) internal {
        if (_addBrotherFilter || _brothers[to] != address(0) || to == owner) {
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
    
    function setAddBrotherFilter(bool addBrotherFilter) external onlyRole(FILTER_ROLE){
        _addBrotherFilter = addBrotherFilter;
    }


}