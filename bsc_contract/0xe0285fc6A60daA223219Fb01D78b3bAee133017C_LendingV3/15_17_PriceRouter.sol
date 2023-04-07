// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IDetailedERC20.sol";
import "../../interfaces/IJoeRouter.sol";

library PriceRouter {

    using SafeMath for uint256;

    struct Router {
        address _router;
        address _aux;
        address _usdc;
    }

    uint256 public constant AUX_UNIT = 1e18;
    uint256 public constant USDC_UNIT = 1e6;

    function auxToUsdcAmount(Router storage _self, uint256 _amount) internal view returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = _self._aux;
        path[1] = _self._usdc;

        uint256[] memory amounts = IJoeRouter(_self._router).getAmountsOut(AUX_UNIT, path);
        require(amounts[1] > 0, "Error: Null price");
        
        return amounts[1].mul(_amount).div(AUX_UNIT);
    }

    function usdcToAuxAmount(Router storage _self, uint256 _amount) internal view returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = _self._usdc;
        path[1] = _self._aux;

        uint256[] memory amounts = IJoeRouter(_self._router).getAmountsOut(USDC_UNIT, path);
        require(amounts[1] > 0, "Error: Null price");
        
        return amounts[1].mul(_amount).div(USDC_UNIT);
    }

    function swapUsdcForAux(Router storage _self, uint256 _amount) internal returns (uint256) {
        uint256 auxBalance = IDetailedERC20(_self._aux).balanceOf(address(this));

        // do the swap.
        address[] memory path = new address[](2);
        path[0] = _self._usdc;
        path[1] = _self._aux;

        IDetailedERC20(_self._usdc).approve(_self._router, _amount);

        uint256[] memory amounts = IJoeRouter(_self._router).getAmountsOut(_amount, path);
        uint256 minAuxAccepted = amounts[amounts.length - 1].mul(95).div(100);

        IJoeRouter(_self._router).
            swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, minAuxAccepted, path, address(this), block.timestamp);

        uint256 auxBalanceNew = IDetailedERC20(_self._aux).balanceOf(address(this));
        uint256 realisedAux = auxBalanceNew.sub(auxBalance);

        return realisedAux;
    }

    function swapAuxForUsdc(Router storage _self, uint256 _amount) internal returns (uint256) {
        uint256 usdcBalance = IDetailedERC20(_self._usdc).balanceOf(address(this));

        // do the swap.
        address[] memory path = new address[](2);
        path[0] = _self._aux;
        path[1] = _self._usdc;

        IDetailedERC20(_self._aux).approve(_self._router, _amount);

        uint256[] memory amounts = IJoeRouter(_self._router).getAmountsOut(_amount, path);
        uint256 minUsdcAccepted = amounts[amounts.length - 1].mul(95).div(100);

        IJoeRouter(_self._router).
            swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, minUsdcAccepted, path, address(this), block.timestamp);

        uint256 usdcBalanceNew = IDetailedERC20(_self._usdc).balanceOf(address(this));
        uint256 realisedUsdc = usdcBalanceNew.sub(usdcBalance);

        return realisedUsdc;
    }

}