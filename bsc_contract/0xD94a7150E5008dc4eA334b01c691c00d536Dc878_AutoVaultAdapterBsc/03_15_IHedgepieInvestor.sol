// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

interface IHedgepieInvestor {
    function treasury() external view returns (address);

    function updateFunds(uint256 _tokenId) external;

    function deposit(uint256 _tokenId) external;

    function withdraw(uint256 _tokenId) external;

    function claim(uint256 _tokenId) external;

    function pendingReward(
        uint256 _tokenId,
        address _account
    ) external returns (uint256 amountOut, uint256 withdrawable);
}