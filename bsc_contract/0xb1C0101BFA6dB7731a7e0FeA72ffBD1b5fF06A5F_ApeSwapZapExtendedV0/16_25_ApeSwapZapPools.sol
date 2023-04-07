// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./lib/IERC20RewardApe.sol";
import "./lib/ITreasury.sol";

abstract contract ApeSwapZapPools is ApeSwapZap {
    using SafeERC20 for IERC20;

    IERC20 public immutable BANANA;
    IERC20 public immutable GNANA;
    ITreasury public immutable GNANA_TREASURY; // Golden Banana Treasury

    event ZapLPPool(IERC20 inputToken, uint256 inputAmount, IERC20RewardApe pool);
    event ZapLPPoolNative(uint256 inputAmount, IERC20RewardApe pool);
    event ZapSingleAssetPool(IERC20 inputToken, uint256 inputAmount, IERC20RewardApe pool);
    event ZapSingleAssetPoolNative(uint256 inputAmount, IERC20RewardApe pool);

    constructor(ITreasury goldenBananaTreasury) {
        ITreasury gnanaTreasury;
        IERC20 banana;
        IERC20 gnana;
        if (block.chainid == 56) {
            /// @dev The Golden Banana Treasury only exists on BNB Chain
            require(address(goldenBananaTreasury) != address(0), "Must provide Golden BANANA Treasury for BNB Chain");
        }

        if (address(goldenBananaTreasury) != address(0)) {
            gnanaTreasury = goldenBananaTreasury;
            banana = gnanaTreasury.banana();
            gnana = gnanaTreasury.goldenBanana();
        } else {
            gnanaTreasury = ITreasury(address(0));
            banana = IERC20(address(0));
            gnana = IERC20(address(0));
        }
        /// @dev Can't access immutable variables in constructor
        /// @dev Can't initialize immutable variables in if statement.
        GNANA_TREASURY = gnanaTreasury;
        BANANA = banana;
        GNANA = gnana;
    }

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapSingleAssetPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IERC20RewardApe pool
    ) external nonReentrant {
        inputAmount = _transferIn(inputToken, inputAmount);
        _zapSingleAssetPool(inputToken, inputAmount, path, minAmountsSwap, deadline, pool);
        emit ZapSingleAssetPool(inputToken, inputAmount, pool);
    }

    /// @notice Zap native into banana/gnana pool
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapSingleAssetPoolNative(
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IERC20RewardApe pool
    ) external payable nonReentrant {
        (IERC20 weth, uint256 inputAmount) = _wrapNative();
        _zapSingleAssetPool(weth, inputAmount, path, minAmountsSwap, deadline, pool);
        emit ZapSingleAssetPoolNative(inputAmount, pool);
    }

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapLPPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IERC20RewardApe pool
    ) external nonReentrant {
        IApePair pair = _validateLpPoolZap(lpTokens, pool);
        inputAmount = _transferIn(inputToken, inputAmount);
        _zap(
            ZapParams({
                inputToken: inputToken,
                inputAmount: inputAmount,
                lpTokens: lpTokens,
                path0: path0,
                path1: path1,
                minAmountsSwap: minAmountsSwap,
                minAmountsLP: minAmountsLP,
                to: address(this),
                deadline: deadline
            }),
            false
        );

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(pool), balance);
        pool.depositTo(balance, msg.sender);
        pair.approve(address(pool), 0);
        emit ZapLPPool(inputToken, inputAmount, pool);
    }

    /// @notice Zap native into banana/gnana pool
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapLPPoolNative(
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IERC20RewardApe pool
    ) external payable nonReentrant {
        IApePair pair = _validateLpPoolZap(lpTokens, pool);
        (IERC20 weth, uint256 inputAmount) = _wrapNative();
        _zap(
            ZapParams({
                inputToken: weth,
                inputAmount: inputAmount,
                lpTokens: lpTokens,
                path0: path0,
                path1: path1,
                minAmountsSwap: minAmountsSwap,
                minAmountsLP: minAmountsLP,
                to: address(this),
                deadline: deadline
            }),
            true
        );

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(pool), balance);
        pool.depositTo(balance, msg.sender);
        pair.approve(address(pool), 0);
        emit ZapLPPoolNative(msg.value, pool);
    }

    /** INTERNAL FUNCTIONs **/

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function _zapSingleAssetPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IERC20RewardApe pool
    ) internal {
        IERC20 stakeToken = pool.STAKE_TOKEN();

        uint256 depositAmount = inputAmount;
        IERC20 neededToken = stakeToken == GNANA ? BANANA : stakeToken;

        if (inputToken != neededToken) {
            require(path[0] == address(inputToken), "ApeSwapZap: wrong path path[0]");
            require(path[path.length - 1] == address(neededToken), "ApeSwapZap: wrong path path[-1]");
            depositAmount = _routerSwap(inputAmount, minAmountsSwap, path, deadline, true);
        }

        if (stakeToken == GNANA) {
            uint256 beforeAmount = _getBalance(stakeToken);
            IERC20(BANANA).approve(address(GNANA_TREASURY), depositAmount);
            GNANA_TREASURY.buy(depositAmount);
            depositAmount = _getBalance(stakeToken) - beforeAmount;
        }

        stakeToken.approve(address(pool), depositAmount);
        pool.depositTo(depositAmount, msg.sender);
        stakeToken.approve(address(pool), 0);
    }

    /** PRIVATE FUNCTIONs **/

    function _validateLpPoolZap(address[] memory lpTokens, IERC20RewardApe pool) private view returns (IApePair pair) {
        pair = IApePair(address(pool.STAKE_TOKEN()));
        require(
            (lpTokens[0] == pair.token0() && lpTokens[1] == pair.token1()) ||
                (lpTokens[1] == pair.token0() && lpTokens[0] == pair.token1()),
            "ApeSwapZapPools: Wrong LP pair for Pool"
        );
    }
}