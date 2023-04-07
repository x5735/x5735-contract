// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '../MatrixLpAutoCompoundV2.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '../../interfaces/IGauge.sol';
import '../../interfaces/equalizer/IEqualizerRouter.sol';

/// @title Pancake Matrix Lp AutoCompound Strategy
contract PancakeMatrixLpAutoCompoundV2 is MatrixLpAutoCompoundV2 {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant THENA_ROUTER = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;

    constructor(
        address _want,
        uint256 _poolId,
        address _masterchef,
        address _output,
        address _uniRouter,
        bool _isStable,
        address _vault,
        address _treasury
    ) MatrixLpAutoCompoundV2(_want, _poolId, _masterchef, _output, _uniRouter, _vault, _treasury) {
        treasury = 0xEaD9f532C72CF35dAb18A42223eE7A1B19bC5aBF;
        USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        wrapped = WBNB;
        isStable = _isStable;

        // Pancakeswap
        routerToType[PANCAKE_ROUTER] = MatrixSwapHelperV2.RouterType.UniV2;

        // Pancake
        routerToType[THENA_ROUTER] = MatrixSwapHelperV2.RouterType.Solidly;

        routers.push(PANCAKE_ROUTER);
        routers.push(THENA_ROUTER);
    }

    function _initialize(
        address _masterchef,
        address _output,
        uint256 _poolId
    ) internal override {
        super._initialize(_masterchef, _output, _poolId);
    }

    function _setWhitelistedAddresses() internal override {
        super._setWhitelistedAddresses();
    }

    function _setDefaultSwapPaths() internal override {
        super._setDefaultSwapPaths();
    }

    function _getRatio(address _lpToken) internal view returns (uint256) {
        address _token0 = IUniswapV2Pair(_lpToken).token0();
        address _token1 = IUniswapV2Pair(_lpToken).token1();

        (uint256 opLp0, uint256 opLp1, ) = IUniswapV2Pair(_lpToken).getReserves();
        uint256 lp0Amt = (opLp0 * (10**18)) / (10**IERC20Metadata(_token0).decimals());
        uint256 lp1Amt = (opLp1 * (10**18)) / (10**IERC20Metadata(_token1).decimals());
        uint256 totalSupply = lp0Amt + (lp1Amt);
        return (lp0Amt * (10**18)) / (totalSupply);
    }
}