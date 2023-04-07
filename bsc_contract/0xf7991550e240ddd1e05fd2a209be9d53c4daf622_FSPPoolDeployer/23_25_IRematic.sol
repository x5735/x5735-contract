// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../struct/Tax.sol';
import '../struct/TaxAmount.sol';

interface IRematic is IERC20 {
    function adminContract() external view returns (address);
    function transferTokenFromPool(address to, uint value) external;

    function buyTax() external returns(Tax memory);
    function sellTax() external returns(Tax memory);
    function tax() external returns(Tax memory);

    function buyTaxAmount() external returns(TaxAmount memory);
    function sellTaxAmount() external returns(TaxAmount memory);
    function taxAmount() external returns(TaxAmount memory);
    
    function burnWallet() external returns(address);
}