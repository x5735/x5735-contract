// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

  event Sync(uint112 reserve0, uint112 reserve1);

  function price0CumulativeLast() external view returns (uint256);

  function price1CumulativeLast() external view returns (uint256);

  function approve(address spender, uint value) external returns (bool);

  function totalSupply() external view returns (uint);

  function skim(address _to) external;

  function sync() external;

  function balanceOf(address owner) external view returns (uint);

  // Specific to Satin
  function partnerAddress() external view returns (address);
}