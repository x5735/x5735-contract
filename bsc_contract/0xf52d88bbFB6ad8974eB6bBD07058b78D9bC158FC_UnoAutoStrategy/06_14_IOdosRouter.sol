// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOdosRouter {
    struct inputToken {
      address tokenAddress;
      uint256 amountIn;
      address receiver;
      bytes permit;
    }

    struct outputToken {
      address tokenAddress;
      uint256 relativeValue;
      address receiver;
    }

 function swap(
    inputToken[] memory inputs,
    outputToken[] memory outputs,
    uint256 valueOutQuote,
    uint256 valueOutMin,
    address executor,
    bytes calldata pathDefinition
  ) external payable returns (uint256[] memory amountsOut, uint256 gasLeft);
}