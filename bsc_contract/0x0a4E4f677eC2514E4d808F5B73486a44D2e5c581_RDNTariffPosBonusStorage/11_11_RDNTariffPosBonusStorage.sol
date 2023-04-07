pragma solidity 0.8.17;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RDNTariffPosBonusStorage is AccessControlEnumerable {

    mapping(uint => uint) public counter;
    mapping(uint => bool) public candidates;
    uint public candidatesCount;

    bytes32 public constant BONUSSTORAGE_WRITE_ROLE = keccak256("BONUSSTORAGE_WRITE_ROLE");

    constructor (address _admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(BONUSSTORAGE_WRITE_ROLE, _admin);
    }

    function setCounter(uint _userId, uint _value) public onlyRole(BONUSSTORAGE_WRITE_ROLE) {
        counter[_userId] = _value;
    }

    function addCounter(uint _userId, uint _value) public onlyRole(BONUSSTORAGE_WRITE_ROLE) {
        counter[_userId] += _value;
    }

    function setCandidate(uint _userId, bool _value) public onlyRole(BONUSSTORAGE_WRITE_ROLE) {
        if ((candidates[_userId] == false) && (_value == true)) {
            candidatesCount += 1;
        }
        if ((candidates[_userId] == true) && (_value == false)) {
            candidatesCount -= 1;
        }
        candidates[_userId] = _value;
    }

    function getCounter(uint _userId) public view returns(uint) {
        return counter[_userId];
    }

    function isCandidate(uint _userId) public view returns(bool) {
        return candidates[_userId];
    }

    function getCandidatesCount() public view returns(uint) {
        return candidatesCount;
    }


}