// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IStakerThena {

    function thenaStake(
        address _baseToken, 
        address _pair,
        address _gauge,
        uint256 _fee,
        address _swapRouter, 
        bytes calldata _swapRouterCallData
    ) external;

    function thenaUnstake(
        address payable _to0,
        address payable _to1,
        address payable _toUSDT,
        address _pair,
        address _gauge,
        uint256 _fee0,
        uint256 _fee1
    ) external;


    function thenaClaimReward(
        address _toUSDT,
        address _pair,
        address _gauge,
        uint _feeUSDT
    ) external;
}