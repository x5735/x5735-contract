//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../library/EGoldUtils.sol";

contract EGoldIdentity is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    mapping(address => EGoldUtils.userData) private Users;

    constructor() AccessControl() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setUser( address _addr ,  EGoldUtils.userData memory userData) external onlyRole(TREASURY_ROLE) {
        Users[_addr] = userData;
    }

    function setRank( address _addr,  uint256 _rank) external onlyRole(TREASURY_ROLE) {
        Users[_addr].rank = _rank;
    }

    function setSales( address _addr, uint256 _sn , uint256 _sales) external onlyRole(TREASURY_ROLE) {
        Users[_addr].sales = _sales;
        Users[_addr].sn = _sn;
    }

    function setParent( address _addr,  address _parent) external onlyRole(TREASURY_ROLE) {
        Users[_addr].parent = _parent;
    }

    function fetchUser( address _addr ) external view returns ( EGoldUtils.userData memory ) {
        return Users[_addr];
    }

    function fetchParent( address _addr ) external view returns ( address ) {
        return Users[_addr].parent;
    }

    function fetchRank( address _addr ) external view  returns ( uint256 ) {
        return Users[_addr].rank;
    }

    function fetchSales( address _addr ) external view  returns ( uint256 , uint256 ) {
        return ( Users[_addr].sn , Users[_addr].sales );
    }



}