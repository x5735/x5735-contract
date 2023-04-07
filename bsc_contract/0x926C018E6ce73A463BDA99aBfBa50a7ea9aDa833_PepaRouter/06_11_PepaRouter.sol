// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPancakeFactory} from "../interfaces/IPancakeFactory.sol";
import {IPancakePair} from "../interfaces/IPancakePair.sol";
import {IWETH} from "../interfaces/IWETH.sol";

import {PancakeLibrary} from "../libraries/PancakeLibrary.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";

/**
 * Router to allow adding and removing of liquidity to PEPA-ETH without paying transfer fees.
 * Assumes that this contract has infinite approval for WETH and PEPA from NO_FEE_WALLET.
 */
contract PepaRouter {
    address constant public NO_FEE_WALLET = 0x4dcc41E99b56570BC96D4a449E75f5b664245Ba7;
    address constant public PEPA = 0xC3137c696796D69F783CD0Be4aB4bB96814234Aa;
    address constant public FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant public WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    /** Checks to make sure no token balance of NO_FEE_WALLET changes.  */
    modifier noBalanceChange() {
        uint256 balancePepa = IERC20(PEPA).balanceOf(NO_FEE_WALLET);
        uint256 balanceWeth = IERC20(WETH).balanceOf(NO_FEE_WALLET);
        uint256 balanceEth = NO_FEE_WALLET.balance;
        _;
        require(IERC20(PEPA).balanceOf(NO_FEE_WALLET) == balancePepa, "PepeRouter: PEPA balance decreased");
        require(IERC20(WETH).balanceOf(NO_FEE_WALLET) == balanceWeth, "PepeRouter: WETH balance decreased");
        require(NO_FEE_WALLET.balance == balanceEth, "PepeRouter: Eth balance decreased");
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'PepeRouter: EXPIRED');
        _;
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable noBalanceChange ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        require(token == PEPA, "PepeRouter: Pepa only");
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = PancakeLibrary.pairFor(FACTORY, token, WETH);
        // route PEPA through NO_FEE_WALLET to avoid tax
        TransferHelper.safeTransferFrom(token, msg.sender, NO_FEE_WALLET, amountToken);
        TransferHelper.safeTransferFrom(token, NO_FEE_WALLET, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IPancakePair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual noBalanceChange ensure(deadline) returns (uint amountToken, uint amountETH) {
        require(token == PEPA, "PepeRouter: Pepa only");
        // route PEPA through NO_FEE_WALLET to avoid tax
        (amountToken, amountETH) = _removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            NO_FEE_WALLET,
            deadline
        );
        TransferHelper.safeTransferFrom(token, NO_FEE_WALLET, to, amountToken);
        TransferHelper.safeTransferFrom(WETH, NO_FEE_WALLET, address(this), amountETH);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        require(IPancakeFactory(FACTORY).getPair(tokenA, tokenB) != address(0), "Pair does not exist");
        
        (uint reserveA, uint reserveB) = PancakeLibrary.getReserves(FACTORY, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = PancakeLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'PancakeRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = PancakeLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'PancakeRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint
    ) internal virtual returns (uint amountA, uint amountB) {
        address pair = PancakeLibrary.pairFor(FACTORY, tokenA, tokenB);
        IPancakePair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IPancakePair(pair).burn(to);
        (address token0,) = PancakeLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'PancakeRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'PancakeRouter: INSUFFICIENT_B_AMOUNT');
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }
}