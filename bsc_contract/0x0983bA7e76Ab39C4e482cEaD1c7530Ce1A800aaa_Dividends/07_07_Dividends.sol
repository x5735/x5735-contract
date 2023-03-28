// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/*
  Dividends contract
  Built by @okwasabi on Telegram.

  This contract is used to distribute tokens to shareholders.
  You can become a shareholder by locking/depositing 'depositToken' into this contract.
  You can claim your share of tokens by calling 'claimTokens()'.
  You will lose your shareholding if you withdraw your depositToken from this contract.
*/

contract Dividends is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken; // The token to be distributed
    IERC20 public depositToken; // The token used to buy shares in pool
    uint256 public totalShares;
    uint256 public totalDistributedTokens;
    uint256 public claimableTokensPerShare;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public lastClaimedSnapshot;

    event TokensDistributed(uint256 amount);
    event SharesUpdated(address indexed shareholder, uint256 shares);
    event TokensClaimed(address indexed shareholder, uint256 amount);

    constructor(IERC20 _rewardToken, IERC20 _depositToken) {
        rewardToken = _rewardToken;
        depositToken = _depositToken;
    }

    // Allows the owner of the contract to distribute 'rewardToken' to shareholders
    function distributeTokens(uint256 amount) external onlyOwner {
        require(totalShares > 0, 'No shares to distribute tokens to');
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        claimableTokensPerShare += (amount * 1e18) / totalShares;
        totalDistributedTokens += amount;
        emit TokensDistributed(amount);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, 'Invalid amount');
        uint256 balanceBefore = depositToken.balanceOf(address(this));
        depositToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = depositToken.balanceOf(address(this));
        uint256 receivedAmount = balanceAfter - balanceBefore;
        _claimTokens(msg.sender);
        totalShares += receivedAmount;
        shares[msg.sender] += receivedAmount;
        updateUser(msg.sender);
        emit SharesUpdated(msg.sender, shares[msg.sender]);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, 'Invalid amount');
        require(_amount <= shares[msg.sender], 'Insufficient shares');
        _claimTokens(msg.sender);
        totalShares -= _amount;
        shares[msg.sender] -= _amount;
        updateUser(msg.sender);
        depositToken.safeTransfer(msg.sender, _amount);
    }

    function updateShares(
        address shareholder,
        uint256 newShares
    ) external onlyOwner {
        require(shareholder != address(0), 'Invalid shareholder address');
        _claimTokens(shareholder);
        totalShares = totalShares - shares[shareholder] + newShares;
        shares[shareholder] = newShares;
        emit SharesUpdated(shareholder, newShares);
    }

    function claimTokens() external {
        _claimTokens(msg.sender);
    }

    function updateUser(address shareholder) internal {
        lastClaimedSnapshot[shareholder] =
            (shares[shareholder] * claimableTokensPerShare) /
            1e18;
    }

    function _claimTokens(address shareholder) internal {
        uint256 pendingTokens = (shares[shareholder] *
            claimableTokensPerShare) /
            1e18 -
            lastClaimedSnapshot[shareholder];
        //require(pendingTokens > 0, "No tokens to claim");
        lastClaimedSnapshot[shareholder] =
            (shares[shareholder] * claimableTokensPerShare) /
            1e18;
        if (pendingTokens > 0) {
            rewardToken.safeTransfer(shareholder, pendingTokens);
            emit TokensClaimed(shareholder, pendingTokens);
        }
    }

    // View function to see pending tokens on frontend.
    function unclaimed(address shareholder) external view returns (uint256) {
        return
            (shares[shareholder] * claimableTokensPerShare) /
            1e18 -
            lastClaimedSnapshot[shareholder];
    }
}