// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardWallet is Ownable {
  IERC20 public immutable teletreonToken;
  address public deployer;

  event LogRewardsWithdrawal(address indexed receiver, uint256 amount);
  event LogTokenRecovery(address tokenRecovered, uint256 amount);

  constructor(IERC20 _teletreonToken, address _stakingContract) {
    teletreonToken = _teletreonToken;
    deployer = msg.sender;
    transferOwnership(_stakingContract);
  }

  modifier onlyOwnerOrDeployer() {
    require(owner() == _msgSender() || deployer == _msgSender(), "Ownable: caller is not the owner or deployer");
    _;
  }

  function withdraw(address receiver, uint256 _amount) external onlyOwnerOrDeployer {
    require(teletreonToken.balanceOf(address(this)) >= _amount, "Insufficient Balance");
    teletreonToken.transfer(receiver, _amount);
    emit LogRewardsWithdrawal(receiver, _amount);
  }

  function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwnerOrDeployer {
    require(_tokenAddress != address(teletreonToken), "Cannot be main token");
    IERC20(_tokenAddress).transfer(address(msg.sender), _tokenAmount);
    emit LogTokenRecovery(_tokenAddress, _tokenAmount);
  }

  function rescueNative() external onlyOwnerOrDeployer {
    uint256 amount = address(this).balance;
    payable(deployer).transfer(amount);
  }
}