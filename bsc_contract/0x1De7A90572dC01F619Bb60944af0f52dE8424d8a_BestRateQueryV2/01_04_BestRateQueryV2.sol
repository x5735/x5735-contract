// SPDX-License-Identifier: MIT

pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IKalmar {
    function getDestinationReturnAmount(
        uint256 tradingRouteIndex,
        IERC20  src,
        IERC20  dest,
        uint256 srcAmount,
        uint256 fee
    )
    external
    returns(uint256);
}

contract BestRateQueryV2 {
    using SafeMath for uint256;

    IKalmar public kalmyswap;

    constructor(IKalmar _kalmswap) public {
        kalmyswap = _kalmswap;
    }

    function _getRate(
        IERC20  src,
        IERC20  dest,
        uint256 srcAmount,
        uint256 route
    )
    private
    returns (
        uint256 amountOut
    ) {
        // fail-safe getting rate, equal to
        bytes memory payload = abi.encodeWithSelector(kalmyswap.getDestinationReturnAmount.selector, route, src, dest, srcAmount, 0);
        (bool success, bytes memory data) = address(kalmyswap).call(payload);
        if (success) {
            return abi.decode(data, (uint256));
        } else {
            return 0;
        }
    }

    function oneRoute(
        IERC20  src,
        IERC20  dest,
        uint256 srcAmount,
        uint256[] calldata routes
    )
    external
    returns (
        uint256 routeIndex,
        uint256 amountOut
    ) {
        for (uint256 i = 0; i < routes.length; i++) {
            uint256 route = routes[i];
            uint256 _amountOut = _getRate(src, dest, srcAmount, route);
            if (_amountOut > amountOut) {
                amountOut = _amountOut;
                routeIndex = route;
            }
        }
    }

    function splitRoutes(
        IERC20  src,
        IERC20  dest,
        uint256 srcAmount,
        uint256[] calldata routes,
        uint256 parts
    )
    external
    returns (
        uint256[] memory distribution,
        uint256 amountOut
    ) {
        distribution = new uint256[](routes.length);

        if (src == dest) {
            return (distribution, srcAmount);
        }

        uint256[] memory rates;
        uint256[] memory fullRates;
        rates = new uint256[](routes.length);
        fullRates = new uint256[](routes.length);

        for (uint i = 0; i < routes.length; i++) {
            rates[i] = _getRate(src, dest, srcAmount.div(parts), routes[i]);
            fullRates[i] = rates[i];
        }

        for (uint j = 0; j < parts; j++) {
            // Find best part
            uint256 bestIndex = 0;
            for (uint i = 1; i < rates.length; i++) {
                if (rates[i] > rates[bestIndex]) {
                    bestIndex = i;
                }
            }

            // Add best part
            amountOut = amountOut.add(rates[bestIndex]);
            distribution[bestIndex]++;

            // Avoid CompilerError: Stack too deep
            uint256 _srcAmount = srcAmount;
            uint256 x = _srcAmount.mul(distribution[bestIndex] + 1).div(parts);
            // Recalc part if needed
            if (j + 1 < parts) {
                uint256 newRate = _getRate(src, dest, x, routes[bestIndex]);
                if (newRate > fullRates[bestIndex]) {
                    rates[bestIndex] = newRate.sub(fullRates[bestIndex]);
                } else {
                    rates[bestIndex] = 0;
                }
                fullRates[bestIndex] = newRate;
            }
        }
    }
}