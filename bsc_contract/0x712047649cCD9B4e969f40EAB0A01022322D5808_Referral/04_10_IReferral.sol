// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IReferral {

    function getRewards(address _user, bytes32 _type) external view returns (uint256);

    function getReferrer(address _user) external view returns (address);

    function getReferralsCount(address _referrer) external view returns (uint256);

    function userInfo(address _user) external view returns (address, uint256);

    function addReferrer(address _user, address _referrer) external;

    function addRewards(address _user, bytes32 _type, uint256 _total) external;

}