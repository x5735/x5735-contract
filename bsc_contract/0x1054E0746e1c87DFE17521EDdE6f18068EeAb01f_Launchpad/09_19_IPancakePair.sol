// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPancakePair {
  function balanceOf(address owner) external view returns (uint);
  function transfer(address to, uint value) external returns (bool);
  function mint(address to) external returns (uint liquidity);
}