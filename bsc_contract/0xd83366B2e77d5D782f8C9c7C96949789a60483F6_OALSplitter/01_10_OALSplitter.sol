// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Contract to manage distribution of $OAL rewards to holders of tokens
 *
 * @dev Holders of the token are eligable to claim #OAL send to this contract
 * - holders receive an equal split relative to maxSupply
 * - rewards are bound to the tokenId.
 * - unclaimed rewards can be claimed by a new owner after transfer.
 *
 * By RetroBoy.dev (on base of contract by Fab)
 */

contract OALSplitter is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC721Enumerable public immutable token;
    IERC20 public immutable erc20Token;
    uint256 public immutable tokenMaxSupply;

    mapping(uint256 => uint256) private claimedForToken;
    uint256 private totalClaimedForTokens;
    uint256 private rewardPerToken = 0;

    event RewardsReceived(uint256 amount, uint256 rewardPerToken);
    event RewardsClaimed(address holder, uint256 tokenId, uint256 amount);

    constructor(address _token, uint256 _maxSupply, address _erc20Token) {
        token = IERC721Enumerable(_token);
        tokenMaxSupply = _maxSupply;
        erc20Token = IERC20(_erc20Token);
    }

    function receiveRewards(uint256 amount) external {
        erc20Token.safeTransferFrom(msg.sender, address(this), amount);
        rewardPerToken += (amount / tokenMaxSupply);
        emit RewardsReceived(amount, rewardPerToken);
    }

    /**
     * @notice Claim pending rewards of all owned tokens. For more than 1000 tokens owned use {claimForTokensBySize}.
     * @dev This would exceeds max gas costs for > 1000 tokens in caller wallet.
     */
    function claimForTokens() external {
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens owned");
        require(balance <= 1000, "use claimForTokensBySize");

        uint256 totalPending = 0;

        uint256 pending;
        uint256 tokenId;
        for (uint256 i = 0; i < balance; ++i) {
            tokenId = token.tokenOfOwnerByIndex(msg.sender, i);
            pending = rewardPerToken.sub(claimedForToken[tokenId]);

            claimedForToken[tokenId] = claimedForToken[tokenId].add(pending);
            totalPending = totalPending.add(pending);

            emit RewardsClaimed(msg.sender, tokenId, pending);
        }

        totalClaimedForTokens = totalClaimedForTokens.add(totalPending);
        erc20Token.safeTransfer(msg.sender, totalPending);
    }

    /**
     * @notice Claim pending rewards of all owned tokens given a `cursor` and `size` of its token list
     * @dev Use this method for holders with more than 1000 tokens in total
     * @param cursor: cursor
     * @param size: size (max 1000)
     */
    function claimForTokensBySize(uint256 cursor, uint256 size) external {
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens owned");
        require(size <= 1000, "Max claim size exeeded");

        uint256 length = size;
        if (length > balance - cursor) {
            length = balance - cursor;
        }

        uint256 totalPending = 0;

        uint256 pending;
        uint256 tokenId;
        for (uint256 i = 0; i < length; i++) {
            tokenId = token.tokenOfOwnerByIndex(msg.sender, cursor + i);
            pending = rewardPerToken - claimedForToken[tokenId];

            claimedForToken[tokenId] += pending;
            totalPending += pending;

            emit RewardsClaimed(msg.sender, tokenId, pending);
        }

        totalClaimedForTokens += totalPending;

        Address.sendValue(payable(msg.sender), totalPending);
    }

    /**
     * @notice Pending rewards for all tokens of `user`.
     * @dev Use this method for holders with more than 3000 tokens in total
     */
    function pendingForTokensBySize(
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256 pending, uint256 length) {
        uint256 balance = token.balanceOf(user);
        require(size <= 3000, "max size 3000");

        length = size;
        if (length > balance - cursor) {
            length = balance - cursor;
        }

        pending = length.mul(rewardPerToken);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = token.tokenOfOwnerByIndex(user, cursor + i);
            pending = pending.sub(claimedForToken[tokenId]);
        }
        pending = pending.sub(totalClaimedForTokens);
    }

    /**
     * @notice Pending rewards for all tokens of `user`.
     */
    function pendingForTokens(
        address _user
    ) external view returns (uint256) {
        uint256 balance = token.balanceOf(_user);
        require(balance <= 1000, "use pendingForTokensBySize");

        uint256 totalPending = 0;
        uint256 pending;
        uint256 tokenId;
        for (uint256 i = 0; i < balance; ++i) {
            tokenId = token.tokenOfOwnerByIndex(_user, i);
            pending = rewardPerToken.sub(claimedForToken[tokenId]);
            totalPending = totalPending.add(pending);
        }

        return totalPending;
    }

    function walletHoldings(address _user) external view returns (uint256) {
        uint256 balance = token.balanceOf(_user);
        return balance;
    }

    /**
     * @notice Pending rewards for given `_tokenId`.
     */
    function pendingForToken(
        uint256 _tokenId
    ) external view returns (uint256 pending) {
        require(token.ownerOf(_tokenId) != address(0), "Invalid tokenId");
        pending = rewardPerToken.sub(claimedForToken[_tokenId]);
    }

    function recoverFungibleTokens() external onlyOwner {
        uint256 amountToRecover = erc20Token.balanceOf(address(this));
        require(amountToRecover != 0, "Operations: No token to recover");

        erc20Token.safeTransfer(address(msg.sender), amountToRecover);

    }
}