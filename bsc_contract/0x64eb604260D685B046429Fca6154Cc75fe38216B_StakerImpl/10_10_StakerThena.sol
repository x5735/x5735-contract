// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IThenaPair.sol";
import "./interfaces/IGaugeV2.sol";
import "./interfaces/IStakerThena.sol";
import "./interfaces/IRouterV2.sol";


interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}


abstract contract StakerThena is IStakerThena {
    using SafeERC20 for IERC20;

    address immutable FEE_COLLECTOR;

    address constant WETH_ADDRESS     = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant THE_ADDRESS      = 0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11;
    address constant USDT_ADDRESS     = 0x55d398326f99059fF775485246999027B3197955;
    address constant BUSD_ADDRESS     = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant THE_BUSD_ADDRESS = 0x34B897289fcCb43c048b2Cea6405e840a129E021;
    address constant THE_ROUTER       = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;    
    address public constant THENA_FACTORY_ADDRESS = 0xAFD89d21BdB66d00817d4153E055830B1c2B3970;

    error InsufficientBaseBalance();
    error FeeHigherThanBalance(address token, uint balance, uint fee);
    error WethTransferFailer(address _to, uint amount);


    constructor(address _feeCollector) {
        FEE_COLLECTOR = _feeCollector;
    }

    /**
     * 
     * @param _baseToken token that we want to exchange
     * @param _pair thena pair
     * @param _swapRouter Address of a contract that will exchange tokens
     * @param _swapRouterCallData Calldata for the router, the idea is that the calldata must contain a call to router 
     *                            that will exchange a predetermined amount of tokens. After that we'll have both tokens
     *                            we'll be able to stake them.  
     */

    function thenaStake(
        address _baseToken, 
        address _pair,
        address _gauge,
        uint256 _fee,
        address _swapRouter, 
        bytes calldata _swapRouterCallData
    ) 
        external
    {
        // wrap WETH
        if (_baseToken == WETH_ADDRESS) {
            uint256 _availableETH = address(this).balance;
            IWETH(WETH_ADDRESS).deposit{value : _availableETH}();
        }

        {
            uint256 baseBalanceBefore = IERC20(_baseToken).balanceOf(address(this));
            if (baseBalanceBefore == 0) { 
                revert InsufficientBaseBalance();
            }

            // take fee
            IERC20(_baseToken).safeTransfer(FEE_COLLECTOR, _fee);

            // swap 
            IERC20(_baseToken).approve(_swapRouter, baseBalanceBefore - _fee);
            Address.functionCall(_swapRouter, _swapRouterCallData);
        }

        (address token0, address token1) = IThenaPair(_pair).tokens();

        // after the swap we should have pool tokens in almost the same proportion as needed
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));       

        // prevent stack too deep error
        _transferTokensToPair(_pair, token0, token1, token0Balance, token1Balance);

        uint256 liquidity = IThenaPair(_pair).mint(address(this));
        IThenaPair(_pair).approve(_gauge, liquidity);
        // stake
        IGaugeV2(_gauge).deposit(liquidity); 
    }

    function _transferTokensToPair(
        address _pair,
        address _token0,
        address _token1,
        uint _token0Balance,
        uint _token1Balance
    ) 
        internal
    {
        (uint256 reserve0, uint256 reserve1,) = IThenaPair(_pair).getReserves();
        uint256 _token0Amount = reserve0 * _token1Balance / reserve1;
        // §Ö§ã§Ý§Ú §ß§å§Ø§ß§í§Û §Ñ§Þ§Ñ§å§ß§ä0 §Ò§à§Ý§î§ê§Ö §é§Ö§Þ §Õ§à§ã§ä§å§á§ß§í§Û §Ò§Ñ§Ý§Ñ§ß§ã0, §Ù§ß§Ñ§é§Ú§ä §å §ß§Ñ§ã §á§Ö§â§Ö§Ó§Ö§ã §Ó §á§à§Ý§î§Ù§å §Ó§ä§à§â§à§Ô§à §ä§à§Ü§Ö§ß§Ñ,
        // §ã§Ý§Ö§Õ§à§Ó§Ñ§ä§Ö§Ý§î§ß§à §Õ§Ý§ñ §â§Ñ§ã§é§Ö§ä§Ñ §Ý§Ú§Ü§Ó§Ú§Õ§ß§à§ã§ä§Ú §Ú§ã§á§à§Ý§î§Ù§å§Ö§Þ §á§Ö§â§Ó§í§Û §ä§à§Ü§Ö§ß
        if (_token0Amount > _token0Balance) {
            _token0Amount =  _token0Balance; 
        }

        uint256 _token1Amount = reserve1 * _token0Amount / reserve0;

        IERC20(_token0).safeTransfer(_pair, _token0Amount);
        IERC20(_token1).safeTransfer(_pair, _token1Amount);
    }

    function thenaUnstake(
        address payable _to0,
        address payable _to1,
        address payable _toUSDT,
        address _pair,
        address _gauge,
        uint256 _fee0,
        uint256 _fee1
    )
        external
    {
        IGaugeV2(_gauge).withdrawAllAndHarvest();
        uint liquidity = IThenaPair(_pair).balanceOf(address(this));
        IERC20(_pair).safeTransfer(_pair, liquidity);
        IThenaPair(_pair).burn(address(this));
        
        (address token0, address token1) = IThenaPair(_pair).tokens();
      
        IERC20(token0).safeTransfer(FEE_COLLECTOR, _fee0);
        IERC20(token1).safeTransfer(FEE_COLLECTOR, _fee1); 
 
        // we cant use amounts return from `burn` method as we need to account any
        // possible dust that had left from any previous stakes
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        if (token0 == WETH_ADDRESS) {
            _unwrapAndTransferWeth(_to0, token0Balance);
            IERC20(token1).safeTransfer(_to1, token1Balance);         
        } else if (token1 == WETH_ADDRESS) {
            IERC20(token0).safeTransfer(_to0, token0Balance);
            _unwrapAndTransferWeth(_to1, token1Balance);
        } else {
            IERC20(token0).safeTransfer(_to0, token0Balance);
            IERC20(token1).safeTransfer(_to1, token1Balance); 
        }

        _swapAndTransferTHE(_toUSDT, 0);
    }

    function _unwrapAndTransferWeth(address payable _to, uint _amount) internal {
        IWETH(WETH_ADDRESS).withdraw(_amount);
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert WethTransferFailer(_to, _amount);
        }
    }

    function thenaClaimReward(
        address _toUSDT,
        address _pair,
        address _gauge,
        uint _feeUSDT
    ) 
        external
    {
        IGaugeV2(_gauge).getReward();
        _swapAndTransferTHE(_toUSDT, _feeUSDT);
    }

    function _swapAndTransferTHE(
        address _to,
        uint _fee
    )
        internal
    {
        uint theBalance = IERC20(THE_ADDRESS).balanceOf(address(this));
        // if we have no THE on the balance then do nothing
        if (theBalance == 0) {
            return;
        }

        // awlays approving max amount to prevent new writes to the THE token storage
        IERC20(THE_ADDRESS).approve(THE_ROUTER, type(uint256).max);

        IRouterV2.route[] memory routes = new IRouterV2.route[](2);
        routes[0].from = THE_ADDRESS;
        routes[0].to = BUSD_ADDRESS;
        routes[0].stable = false;
        routes[1].from = BUSD_ADDRESS;
        routes[1].to = USDT_ADDRESS;
        routes[1].stable = true;


        uint[] memory amounts = IRouterV2(THE_ROUTER).getAmountsOut(theBalance, routes);
        uint amountOutMin = amounts[amounts.length-1];

        if (_fee > amountOutMin) {
            revert FeeHigherThanBalance(USDT_ADDRESS, amountOutMin, _fee);
        }

        IRouterV2(THE_ROUTER).swapExactTokensForTokens(
            theBalance,
            amountOutMin,
            routes,
            address(this),
            block.timestamp
        );
  
        IERC20(USDT_ADDRESS).safeTransfer(FEE_COLLECTOR, _fee);
        IERC20(USDT_ADDRESS).safeTransfer(_to, amountOutMin - _fee);
    }
}