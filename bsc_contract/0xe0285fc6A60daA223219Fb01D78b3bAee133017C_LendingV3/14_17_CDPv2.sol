// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {FixedPointMath} from "../FixedPointMath.sol";
import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";
import "hardhat/console.sol";

library CDPv2 {
    using CDPv2 for Data;
    using FixedPointMath for FixedPointMath.FixedDecimal;
    using SafeERC20 for IDetailedERC20;
    using SafeMath for uint256;

    struct Context {
        FixedPointMath.FixedDecimal accumulatedYieldWeight;
    }

    struct Data {
        uint256 totalDeposited;       // In USDC, 6-decimals units.
        uint256 lastDeposit;          // In timestamp, not block number.
        uint256 totalCredit;          // In AUX, 18-decimals units.
        FixedPointMath.FixedDecimal lastAccumulatedYieldWeight;
    }

    function update(Data storage _self, Context storage _ctx) internal {
        uint256 _earnedYield = _self.getEarnedYield(_ctx);

        _self.totalCredit = _self.totalCredit.add(_earnedYield);
        _self.lastAccumulatedYieldWeight = _ctx.accumulatedYieldWeight;
    }

    function getEarnedYield(Data storage _self, Context storage _ctx) internal view returns (uint256) {
        FixedPointMath.FixedDecimal memory _currentAccumulatedYieldWeight = _ctx.accumulatedYieldWeight;
        FixedPointMath.FixedDecimal memory _lastAccumulatedYieldWeight = _self.lastAccumulatedYieldWeight;

        if (_currentAccumulatedYieldWeight.cmp(_lastAccumulatedYieldWeight) == 0) {
            return 0;
        }

        return _currentAccumulatedYieldWeight.sub(_lastAccumulatedYieldWeight).mul(_self.totalDeposited).decode();
    }
}