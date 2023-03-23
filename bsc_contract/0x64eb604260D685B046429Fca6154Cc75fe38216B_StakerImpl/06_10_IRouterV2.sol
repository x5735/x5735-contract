// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IRouterV2 {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function getAmountsOut(
        uint amountIn, 
        route[] memory routes
    ) external view returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}