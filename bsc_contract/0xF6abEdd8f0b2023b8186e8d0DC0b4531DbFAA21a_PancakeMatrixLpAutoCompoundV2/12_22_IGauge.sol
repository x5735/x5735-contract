// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IGauge {

    function deposit(uint256 _amount, uint256 _tokenId) external;
    function depositAll(uint256 _tokenId) external;
    function withdraw(uint _amount) external;
    function withdrawAll() external;
    function claimFees() external;
    function getReward(address _account, address[] memory _tokens) external;
    function earned(address _token, address _account) external view returns (uint256);
    function balanceOf(address _from) external view returns (uint256);
}