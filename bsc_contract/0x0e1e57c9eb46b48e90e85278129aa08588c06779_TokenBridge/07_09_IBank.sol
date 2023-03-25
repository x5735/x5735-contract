// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBank {
    
    event Approved(address indexed owner, address indexed spender, uint256 value);

    event Deposited(address indexed source, address indexed target, uint256 amount);

    event Withdrawn(address indexed source, address indexed target, uint256 amount);

    function balanceOf(address account) external view returns (uint256);
    
    function deposit(uint256 amount) external returns (bool);
    
    function depositFor(address addr, uint256 amount) external returns (bool);

    function withdraw(uint256 amount) external returns (bool);
    
    function withdrawFrom(address addr, uint256 amount) external returns (bool);
    
    function allowance(address owner, address spender) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);
    
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}