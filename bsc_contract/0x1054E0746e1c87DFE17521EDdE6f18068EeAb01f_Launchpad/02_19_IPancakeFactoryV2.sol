// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPancakeFactoryV2 {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
  function createPair(address tokenA, address tokenB) external returns (address pair);
}