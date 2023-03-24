// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import './IUnoFarmFactory.sol';
import './IUnoAccessManager.sol'; 
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

interface IUnoAssetRouter {
    event Deposit(address indexed lpPool, address indexed from, address indexed recipient, uint256 amount);
    event Withdraw(address indexed lpPool, address indexed from, address indexed recipient, uint256 amount);
    event Distribute(address indexed lpPool, uint256 reward);

    function farmFactory() external view returns(IUnoFarmFactory);
    function accessManager() external view returns(IUnoAccessManager);

    function initialize(address _accessManager, address _farmFactory) external;

    function deposit(address lpPool, uint256 amountA, uint256 amountB, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 sentA, uint256 sentB, uint256 liquidity);
    function depositETH(address lpPair, uint256 amountToken, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external payable returns(uint256 sentToken, uint256 sentETH, uint256 liquidity);
    function depositSingleAsset(address lpPair, address token, uint256 amount, bytes[2] calldata swapData, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 sent, uint256 liquidity);
    function depositSingleETH(address lpPair, bytes[2] calldata swapData, uint256 amountAMin, uint256 amountBMin, address recipient) external payable returns(uint256 sentETH, uint256 liquidity);
    function depositLP(address lpPair, uint256 amount, address recipient) external;

    function withdraw(address lpPool, uint256 amount, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 amountA, uint256 amountB);
    function withdrawETH(address lpPair, uint256 amount, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external returns(uint256 amountToken, uint256 amountETH);
    function withdrawSingleAsset(address lpPair, uint256 amount, address token, bytes[2] calldata swapData, address recipient) external returns(uint256 amountToken, uint256 amountA, uint256 amountB);
    function withdrawSingleETH(address lpPair,  uint256 amount, bytes[2] calldata swapData, address recipient) external returns(uint256 amountETH, uint256 amountA, uint256 amountB);
    function withdrawLP(address lpPair, uint256 amount, address recipient) external;

    function userStake(address _address, address lpPool) external view returns (uint256 stakeLP, uint256 stakeA, uint256 stakeB);
    function totalDeposits(address lpPool) external view returns (uint256 totalDepositsLP, uint256 totalDepositsA, uint256 totalDepositsB);
    function getTokens(address lpPool) external view returns(address[] memory tokens);

    function paused() external view returns(bool);
    function pause() external;
    function unpause() external;

    function upgradeTo(address newImplementation) external;
}