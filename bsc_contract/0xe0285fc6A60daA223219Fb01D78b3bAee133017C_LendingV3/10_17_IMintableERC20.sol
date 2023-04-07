// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;


import {IDetailedERC20} from "./IDetailedERC20.sol";

interface IMintableERC20 is IDetailedERC20{
  function mint(address _recipient, uint256 _amount) external;
  function burnFrom(address account, uint256 amount) external;
  function hasMinted(address sender) external returns (uint256);
  function lowerHasMinted(uint256 amount)external;
}