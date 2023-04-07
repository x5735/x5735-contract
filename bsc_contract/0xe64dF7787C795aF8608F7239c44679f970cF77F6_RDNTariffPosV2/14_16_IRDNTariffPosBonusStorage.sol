// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IRDNTariffPosBonusStorage {

    function setCounter(uint _userId, uint _value) external;

    function addCounter(uint _userId, uint _value) external;

    function setCandidate(uint _userId, bool _value) external;

    function getCounter(uint _userId) external view returns(uint);

    function isCandidate(uint _userId) external view returns(bool);

    function getCandidatesCount() external view returns(uint);

}