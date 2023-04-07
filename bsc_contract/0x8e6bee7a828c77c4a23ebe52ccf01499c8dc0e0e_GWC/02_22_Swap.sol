// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract Swap{

    uint256 backPool;
    address private _tokenReceiver;
    address private _lpAddress;

    function getUniswapV2Pair() public view virtual returns(IUniswapV2Pair);

    function getUniswapV2Router02() public view virtual returns(IUniswapV2Router02);

    function _approve(address owner, address spender, uint256 amount) internal virtual;

    constructor(address tokenReceiver) {
        _lpAddress = msg.sender;
        _tokenReceiver = tokenReceiver;
    }

    function _addPool(uint256 number) internal{
        backPool += number;
    }

    function _addLiquidity() internal{
        uint256 amount = backPool;
        if (IERC20(address(this)).balanceOf(address(this)) < amount 
            || IERC20(address(getUniswapV2Pair())).totalSupply() < 1000
            || msg.sender == address(getUniswapV2Pair())) return;
        address token = getUniswapV2Pair().token0();
        token = token != address(this) ? token : getUniswapV2Pair().token1();
        uint256 amountOut = IERC20(token).balanceOf(_tokenReceiver);
        _approve(address(this), address(getUniswapV2Router02()), amount);
        amount = amount / 2;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = token;
        
        getUniswapV2Router02().swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0,
            path,
            _tokenReceiver,
            block.timestamp
        );
        amountOut = IERC20(token).balanceOf(_tokenReceiver) - amountOut;
        IERC20(token).transferFrom(_tokenReceiver, address(this), amountOut);

        IERC20(token).approve(address(getUniswapV2Router02()), amountOut);
        getUniswapV2Router02().addLiquidity(
            token,
            address(this),
            amountOut,
            amount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _lpAddress,
            block.timestamp
        );
        backPool = 0;
    }

}