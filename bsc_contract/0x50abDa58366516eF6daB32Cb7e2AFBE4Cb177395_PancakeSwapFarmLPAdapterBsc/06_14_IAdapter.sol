// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./IWrap.sol";
import "../base/BaseAdapter.sol";

interface IAdapter {
    function stakingToken() external view returns (address);

    function strategy() external view returns (address);

    function name() external view returns (string memory);

    function rewardToken() external view returns (address);

    function rewardToken1() external view returns (address);

    function router() external view returns (address);

    function swapRouter() external view returns (address);

    function authority() external view returns (address);

    function deposit(
        uint256 _tokenId
    ) external payable returns (uint256 amountOut);

    function withdraw(
        uint256 _tokenId,
        uint256 _amount
    ) external payable returns (uint256 amountOut);

    function claim(
        uint256 _tokenId
    ) external payable returns (uint256 amountOut);

    function pendingReward(
        uint256 _tokenId
    ) external view returns (uint256 amountOut, uint256 withdrawable);

    function adapterInfos(
        uint256 _tokenId
    ) external view returns (BaseAdapter.AdapterInfo memory);

    function userAdapterInfos(
        uint256 _tokenId
    ) external view returns (BaseAdapter.UserAdapterInfo memory);

    function mAdapter() external view returns (BaseAdapter.AdapterInfo memory);

    function removeFunds(
        uint256 _tokenId
    ) external payable returns (uint256 amount);

    function getUserAmount(
        uint256 _tokenId
    ) external view returns (uint256 amount);

    function updateFunds(
        uint256 _tokenId
    ) external payable returns (uint256 amount);
}