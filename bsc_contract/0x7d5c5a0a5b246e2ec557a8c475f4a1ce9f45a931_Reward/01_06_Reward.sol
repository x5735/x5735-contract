// SPDX-License-Identifier: GPL

pragma solidity 0.8.0;

import "./libs/fota/Auth.sol";
import "./libs/fota/MerkelProof.sol";
import "./interfaces/IFOTAToken.sol";

contract Reward is Auth {

  struct User {
    uint lastClaimedAt;
    uint allocated;
    uint totalClaimed;
  }

  bytes32 public rootHash;
  IFOTAToken public fotaToken;
  uint public constant secondsInOneMonth = 86400 * 30;
  uint public constant tgeRatio = 20;
  uint public startVestingAt;
  mapping(address => User) public users;

  event Claimed(address indexed user, uint amount, uint timestamp);
  event VestingStated(uint timestamp);

  function initialize(address _mainAdmin, address _fotaToken) public initializer {
    Auth.initialize(_mainAdmin);
    fotaToken = IFOTAToken(_fotaToken);
    rootHash = 0x8b209080c12f17ba0f81f82b1a76f07bcad049c52152255cf396ae49595a1039;
  }

  function setRootHash(bytes32 _rootHash) onlyMainAdmin external {
    rootHash = _rootHash;
  }

  function startVesting() onlyMainAdmin external {
    require(startVestingAt == 0, "Reward: vesting had started");
    startVestingAt = block.timestamp;
    emit VestingStated(startVestingAt);
  }

  function claim(uint _allocated, bytes32[] calldata _path) external {
    require(startVestingAt > 0, "Reward: please wait more time");
    _verifyUser(_allocated, _path);
    User storage user = users[msg.sender];
    uint claimingAmount;
    if (user.lastClaimedAt == 0) {
      user.allocated = _allocated;
      user.lastClaimedAt = startVestingAt;
      claimingAmount = user.allocated * tgeRatio / 100;
    } else {
      require(block.timestamp - user.lastClaimedAt >= secondsInOneMonth, "Reward: please comeback later");
      user.lastClaimedAt += secondsInOneMonth;
      claimingAmount = (user.allocated - user.totalClaimed) * 20 / 100;
    }
    user.totalClaimed += claimingAmount;
    require(fotaToken.balanceOf(address(this)) >= claimingAmount, "Reward: contract is insufficient balance");
    fotaToken.transfer(msg.sender, claimingAmount);
    emit Claimed(msg.sender, claimingAmount, block.timestamp);
  }

  // PRIVATE FUNCTIONS

  function _verifyUser(uint _allocated, bytes32[] calldata _path) private view {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, _allocated));
    require(MerkleProof.verify(_path, rootHash, hash), 'Reward: 400');
  }
}