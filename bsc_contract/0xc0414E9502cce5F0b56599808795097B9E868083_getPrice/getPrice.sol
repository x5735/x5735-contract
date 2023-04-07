/**
 *Submitted for verification at BscScan.com on 2023-03-31
*/

/**
 *Submitted for verification at BscScan.com on 2023-03-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function _approve(address owner, address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract getPrice{

    using SafeMath for uint256;

    IPancakeRouter01 public Router;
    IERC20 public LAR;
    IERC20 public BUSD;
    IERC20 public WIRE;
    IERC20 public Cake;

    address public WETH;

    address LpReceiver;
    address BUSDReceiver;

    constructor(IERC20 _busd) {
        WIRE = IERC20(0x3b3CD14d6D2fc39A68630582c2EB8ec98C21A81e);
        Cake = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
        LAR = IERC20(0x052775Cf897b3eC894F26b8d801C514123c305D1); 
        BUSD = _busd;
        // 0xe9e7cea3dedca5984780bafc599bd69add087d56
        Router = IPancakeRouter01(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        WETH = Router.WETH();
        LpReceiver = 0xB6DC6721Bc86120166128b5Fd56dF349Df85A993;
        BUSDReceiver = 0xB6DC6721Bc86120166128b5Fd56dF349Df85A993;
    }

    function BUSDtobnb (uint256 amountIn) public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = Router.WETH();
        uint256[] memory amounts = Router.getAmountsOut(amountIn,path);
        return amounts[1];
    }

    function Wiretobnb(uint256 amountIn) public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = address(WIRE);
        path[1] = Router.WETH();
        uint256[] memory amounts = Router.getAmountsOut(amountIn,path);
        return amounts[1];
    }

    function bnbtoWire(uint256 amountIn) public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = Router.WETH();
        path[1] = address(WIRE);
        uint256[] memory amounts = Router.getAmountsOut(amountIn,path);
        return amounts[1];
    }

    function BnbtoLar (uint256 amountIn) public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = Router.WETH();
        path[1] = address(LAR);
        uint256[] memory amounts = Router.getAmountsOut(amountIn,path);
        return amounts[1];
    }

    function BnbtoBusd (uint256 amountIn) public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = Router.WETH();
        path[1] = address(BUSD);
        uint256[] memory amounts = Router.getAmountsOut(amountIn,path);
        return amounts[1];
    }

    uint256 twentyWire = 20 ether;
    uint256 fiftyLar = 50 ether;

    function Twenty$Wire () public view returns (uint256){
        address[] memory path = new address[](4);
        path[0] = address(BUSD);
        path[1] = address(Cake);
        path[2] = Router.WETH();
        path[3] = address(WIRE);
        uint256[] memory amounts = Router.getAmountsOut(twentyWire,path);
        return amounts[3];
    }

    function fifty$Lar () public view returns (uint256){
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(LAR);
        uint256[] memory amounts = Router.getAmountsOut(fiftyLar,path);
        return amounts[1];
    }

    // function fifty$Lar () public view returns (uint256){
    //     address[] memory path = new address[](3);
    //     path[0] = address(BUSD);
    //     path[1] = Router.WETH();
    //     path[2] = address(LAR);
    //     uint256[] memory amounts = Router.getAmountsOut(fiftyLar,path);
    //     return amounts[2];
    // }


    // function value(uint256 _amt) public view returns(uint256,uint256)
    // {
    //     uint256 a = _amt/2;
    //     uint256 bnbamount = (BnbtoBusd(_amt).mul(a)).div(1e18);
    //     uint256 tokenamount = a.mul(onedollar(_amt)).div(1e18);
    //     return (bnbamount,tokenamount);
    // }



}