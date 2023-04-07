// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '../interfaces/IUniswapV2Pair.sol';
import '../interfaces/ISolidlyRouter.sol';
import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

/// @title Swap Helper to perform swaps and setting routes in matrix zap
contract MatrixSwapHelperV2 {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address[] public routers;
    mapping(address => bool) public validRouter;

    /// @dev Enumerable set of external tokens and routers
    /// strategy can interact with
    EnumerableSet.AddressSet internal whitelistedAddresses;

    enum RouterType {
        UniV2,
        Solidly
    }

    struct SwapPath {
        RouterType routerType;
        address unirouter;
        address[] path;
    }

    mapping(bytes32 => SwapPath) internal swapPaths;

    constructor(address _uniRouter) {
        routers.push(_uniRouter);
        validRouter[_uniRouter] = true;
    }

    function getWhitelistedAddresses() public virtual returns (address[] memory) {
        return whitelistedAddresses.values();
    }

    function getSwapPath(
        address _fromToken,
        address _toToken,
        address _unirouter
    ) public view virtual returns (SwapPath memory _swapPath) {
        bytes32 _swapKey = keccak256(abi.encodePacked(_fromToken, _toToken, _unirouter));
        require(swapPaths[_swapKey].unirouter != address(0), 'path-not-found');
        return swapPaths[_swapKey];
    }

    function reversePath(address[] memory _path) public pure returns (address[] memory) {
        uint256 length = _path.length;
        address[] memory reversedPath = new address[](length);
        uint256 x = 0;

        for (uint256 i = length; i >= 1; i--) {
            reversedPath[x] = _path[i - 1];
            x++;
        }

        return reversedPath;
    }

    function _setSwapPath(
        address _fromToken,
        address _toToken,
        address _unirouter,
        address[] memory _path
    ) internal virtual {
        require(_path[0] == _fromToken, 'invalid-path');
        require(_path[_path.length - 1] == _toToken, 'invalid-path');
        require(_unirouter != address(0), 'invalid-router');

        _checkPath(_path);

        bytes32 _swapKey = keccak256(abi.encodePacked(_fromToken, _toToken, _unirouter));
        bytes32 _swapKeyReverse = keccak256(abi.encodePacked(_toToken, _fromToken, _unirouter));
        address _router = _unirouter;

        _checkRouter(_router);

        // setting path
        swapPaths[_swapKey] = SwapPath(RouterType.UniV2, _router, _path);

        // setting also reverse path
        swapPaths[_swapKeyReverse] = SwapPath(RouterType.UniV2, _router, reversePath(_path));
    }

    /// @dev Checks that tokens in path are whitelisted
    /// @notice Override this to skip checks
    function _checkPath(address[] memory _path) internal virtual {
        for (uint256 i; i < _path.length; i++) {
            //console.log(_path[i]);
            require(whitelistedAddresses.contains(_path[i]), 'token-not-whitelisted');
        }
    }

    /// @dev Checks that router for swap is whitelisted
    /// @notice Override this to skip checks
    function _checkRouter(address _router) internal virtual {
        require(whitelistedAddresses.contains(_router), 'router-not-whitelisted');
    }

    function _swap(
        SwapPath memory _swapPath,
        uint256 _amount,
        RouterType _type
    ) internal virtual returns (uint256 _toTokenAmount) {
        address _fromToken = _swapPath.path[0];
        address _toToken = _swapPath.path[_swapPath.path.length - 1];

        // check for same token
        if (_fromToken == _toToken) return _amount;

        IERC20(_fromToken).safeApprove(_swapPath.unirouter, 0);
        IERC20(_fromToken).safeApprove(_swapPath.unirouter, type(uint256).max);

        // debugging: uncomment this block
        // console.log("router:", _swapPath.unirouter);
        // console.log("_fromToken:", IERC20Metadata(_fromToken).symbol());
        // console.log("_toToken", IERC20Metadata(_toToken).symbol());
        // console.log("_path:");
        // console.log("_amountIn", _amount);
        // balanceOf _fromToken
        // console.log("balanceOf _fromToken", IERC20(_fromToken).balanceOf(address(this)));
        // for (uint i; i < _swapPath.path.length; i++) {
        //     console.log(_swapPath.path[i], " - ", IERC20Metadata(_swapPath.path[i]).symbol());
        // }

        uint256 _toTokenBefore = IERC20(_toToken).balanceOf(address(this));

        if (_type == RouterType.UniV2) {
            IUniswapV2Router02(_swapPath.unirouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 1, _swapPath.path, address(this), block.timestamp);
        } else if (_type == RouterType.Solidly) {
            ISolidlyRouter(_swapPath.unirouter).swapExactTokensForTokens(_amount, 1, _pathToSolidlyPath(_amount, _swapPath.unirouter, _swapPath.path), address(this), block.timestamp);
        } else {
            revert('invalid-router-type');
        }

        _toTokenAmount = IERC20(_toToken).balanceOf(address(this)) - _toTokenBefore;
    }

    function _pathToSolidlyPath(
        uint256 _amount,
        address _router,
        address[] memory _path
    ) internal view returns (ISolidlyRouter.route[] memory) {
        ISolidlyRouter.route[] memory _solidlyPath = new ISolidlyRouter.route[](_path.length - 1);

        for (uint256 i; i < _path.length - 1; i++) {
            // check max out
            (uint256 amount, bool stable) = ISolidlyRouter(_router).getAmountOut(_amount, _path[i], _path[i + 1]);

            _solidlyPath[i] = ISolidlyRouter.route(_path[i], _path[i + 1], stable);
            _amount = amount;
        }

        return _solidlyPath;
    }

    function _estimateSwap(
        SwapPath memory _swapPath,
        uint256 _amount,
        RouterType _type
    ) internal view virtual returns (uint256) {
        address _fromToken = _swapPath.path[0];
        address _toToken = _swapPath.path[_swapPath.path.length - 1];

        // check for same token
        if (_fromToken == _toToken) return _amount;

        // Uniswap
        if (_type == RouterType.UniV2) {
            // can revert if pair doesn't exist
            try IUniswapV2Router02(_swapPath.unirouter).getAmountsOut(_amount, _swapPath.path) returns (uint256[] memory amounts) {
                return amounts[amounts.length - 1];
            } catch {
                return 0;
            }
        }

        // Solidly
        if (_type == RouterType.Solidly) {
            // converting path
            ISolidlyRouter.route[] memory _solidlyPath = _pathToSolidlyPath(_amount, _swapPath.unirouter, _swapPath.path);

            // can revert if pair doesn't exist
            try ISolidlyRouter(_swapPath.unirouter).getAmountsOut(_amount, _solidlyPath) returns (uint256[] memory amounts) {
                return amounts[amounts.length - 1];
            } catch {
                console.log('something reverted, returning 0');
                return 0;
            }
        }

        return 0;
    }

    function _addRouter(address _router) internal virtual {
        require(_router != address(0), 'invalid-router');
        require(validRouter[_router] == false, 'router-already-added');
        routers.push(_router);
        validRouter[_router] = true;
        whitelistedAddresses.add(_router);
    }
}