// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IReferral.sol";

contract Referral is IReferral, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address => address) private users;
    mapping(address => mapping(bytes32 => uint256)) private rewards;
    mapping(address => uint256) private referralsCount;

    uint256 totalReferrals;

    event ReferrerAdded(address indexed _user, address indexed _referrer);
    event RewardsAdded(address indexed _user, bytes32 indexed _type, uint256 _total);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
    }

    function toBytes32(string calldata _type) external pure returns(bytes32) {
        return keccak256(abi.encodePacked(_type));
    }

    function getRewards(address _user, bytes32 _type) override external view returns (uint256) {
        return rewards[_user][_type];
    }

    function getReferrer(address _user) override external view returns (address) {
        return users[_user];
    }

    function getReferralsCount(address _referrer) override external view returns (uint256) {
        return referralsCount[_referrer];
    }

    function userInfo(address _user) override external view returns(address, uint256) {
        return (users[_user], referralsCount[_user]);
    }

    function addReferrer(address _user, address _referrer) override external onlyRole(OPERATOR_ROLE) {
        require(_user != address(0), "user_zero");
        require(_referrer != address(0), "referrer_zero");
        require(_user != _referrer, "user_is_equal_referrer");
        require(users[_user] == address(0), "referrer_exists");

        users[_user] = _referrer;
        referralsCount[_referrer] = referralsCount[_referrer].add(1);
        totalReferrals = totalReferrals.add(1);

        emit ReferrerAdded(_user, _referrer);
    }

    function addRewards(address _user, bytes32 _type, uint256 _total) override external onlyRole(OPERATOR_ROLE) {
        require(_user != address(0), "user_zero");
        require(_total > 0, "total_zero");

        rewards[_user][_type] = rewards[_user][_type].add(_total);

        emit RewardsAdded(_user, _type, _total);
    }

}