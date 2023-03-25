// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Uniswap v2
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";

// Uniswap v3
import "./IUniswapV3Factory.sol";
import "./IUniswapV3Pool.sol";
import "./ISwapRouter.sol";

// OpenZeppelin
import "./ReentrancyGuard.sol";
import "./ERC165.sol";
import "./ERC20.sol";
import "./Ownable.sol";

interface IWETH {
    function withdraw(uint256 amount) external;
}

interface IPairV2 {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IPairV3 {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external;
}

/**
* @dev Struct containing variables needed for a swap
*
* @param input The input token address
* @param output The output token address
* @param token0 The token0 address for swaps
* @param amountInput The input token amount
* @param amountOutput The output token amount
*/
struct SwapVariables {
    address input;
    address output;
    address token0;
    uint amountInput;
    uint amountOutput;
}

/**
 * @dev Contract for a decentralized exchange network
 */
contract DecentralizedExchangeNetwork is Ownable, ReentrancyGuard {
    uint8 public systemFeeNumerator = 15; // Numerator for the system fee percentage
    uint8 public ownerFeeNumerator = 20; // Numerator for the owner fee percentage
    uint8 public maxTotalFeeNumerator = 250; // Maximum total fee percentage numerator
    uint16 public feeDenominator = 10000; // Fee denominator for percentage calculation
    uint24 public feeTierV3 = 3000; // Fee tier for Uniswap V3 swaps
    uint64 public swapTokenForETHCount = 0; // Counter for token-to-ETH swaps
    uint64 public swapETHForTokenCount = 0; // Counter for ETH-to-token swaps
    uint64 public swapTokenForTokenCount = 0; // Counter for token-to-token swaps
    uint256 public systemFeesCollected = 0; // Total system fees collected
    uint256 public ownerFeesCollected = 0; // Total owner fees collected
    address public systemFeeReceiver; // Address to receive system fees, 0x0aaA18c723B3e57df3988c4612d4CC7fAdD42a34
    address public ownerFeeReceiver; // Address to receive owner fees, 0x091dD81C8B9347b30f1A4d5a88F92d6F2A42b059

    // Wrapped Native Coin
    // 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 (Wrapped ETH)
    // 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c (Wrapped BSC)
    // 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270 (Wrapped MATIC)
    // 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 (Wrapped AVAX)
    // 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83 (Wrapped FTM)
    // 0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a (Wrapped ONE)
    // 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 (Wrapped Arbitrum)
    address public WETH;

    /**
    * @dev Emitted when the owner fee numerator is changed
    *
    * @param oldFeeNumerator The old owner fee numerator
    * @param newFeeNumerator The new owner fee numerator
    */
    event OwnerFeeNumeratorChanged(
        uint oldFeeNumerator,
        uint newFeeNumerator
    );

    /**
    * @dev Emitted when the owner fee receiver address is changed
    *
    * @param oldOwnerFeeReceiver The old owner fee receiver address
    * @param newOwnerFeeReceiver The new owner fee receiver address
    */
    event OwnerFeeReceiverChanged(
        address indexed oldOwnerFeeReceiver,
        address indexed newOwnerFeeReceiver
    );

    /**
    * @dev Constructor for the contract
    *
    * @param WETH_ Address of the WETH contract
    * @param systemFeeReceiver_ Address of the system fee receiver
    * @param ownerFeeReceiver_ Address of the owner fee receiver
    */
    constructor( // test params: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0x0aaA18c723B3e57df3988c4612d4CC7fAdD42a34, 0x091dD81C8B9347b30f1A4d5a88F92d6F2A42b059
        address WETH_,
        address systemFeeReceiver_,
        address ownerFeeReceiver_
    ) {
        // Check for valid inputs
        require(WETH_ != address(0), "Zero Address for WETH");
        require(systemFeeReceiver_ != address(0), "Zero Address for systemFeeReceiver");
        require(ownerFeeReceiver_ != address(0), "Zero Address for ownerFeeReceiver");

        // Set the values for the WETH contract, system fee receiver, and owner fee receiver
        WETH = WETH_;
        systemFeeReceiver = systemFeeReceiver_;
        ownerFeeReceiver = ownerFeeReceiver_;
    }

    /**
    * @dev Sets the owner fee numerator
    *
    * @param newOwnerFeeNumerator The new owner fee numerator to set
    */
    function setOwnerFeeNumerator(uint8 newOwnerFeeNumerator) external onlyOwner {
        require(newOwnerFeeNumerator <= (maxTotalFeeNumerator - systemFeeNumerator), "Fee Too High");

        // Emit an event to notify of the change
        emit OwnerFeeNumeratorChanged(ownerFeeNumerator, newOwnerFeeNumerator);

        // Set the new owner fee numerator
        ownerFeeNumerator = newOwnerFeeNumerator;
    }

    /**
    * @dev Sets the owner fee receiver address
    *
    * @param newOwnerFeeReceiver The new owner fee receiver address to set
    */
    function setOwnerFeeReceiver(address newOwnerFeeReceiver) external onlyOwner {
        require(newOwnerFeeReceiver != address(0), "Zero Address");

        // Emit an event to notify of the change
        emit OwnerFeeReceiverChanged(ownerFeeReceiver, newOwnerFeeReceiver);

        // Set the new owner fee receiver address
        ownerFeeReceiver = newOwnerFeeReceiver;
    }

    /**
    * @dev Swaps a specified amount of ETH for ERC20 tokens
    *
    * @param DEX Address of the DEX contract
    * @param token Address of the ERC20 token to swap for
    * @param amountOutMin Minimum amount of `token` that must be received for the swap to be considered successful
    */
    function swapETHForToken(
        address DEX,
        address token,
        uint amountOutMin
    ) external payable nonReentrant {
        // Check for valid inputs
        require(DEX != address(0), "Zero Address for DEX");
        require(token != address(0), "Zero Address for token");
        require(amountOutMin > 0, "Zero Value for amountOutMin");
        require(msg.value > 0, "Zero Value for msg.value");

        // Handle the fees
        (uint systemFee, uint ownerFee) = getFees(msg.value);
        _sendETH(systemFeeReceiver, systemFee);
        _sendETH(ownerFeeReceiver, ownerFee);
        uint amountInLessFees = msg.value - (systemFee + ownerFee);

        // Swap with the right DEX version
        uint8 version = getUniswapVersion(DEX);
        if (version == 3) {
            swapETHForTokenV3(DEX, token, amountInLessFees, amountOutMin);
        } else if (version == 2) {
            swapETHForTokenV2(DEX, token, amountInLessFees, amountOutMin);
        } else {
            revert("Unsupported DEX");
        }

        // Update counters
        swapETHForTokenCount++;
        systemFeesCollected += systemFee;
        ownerFeesCollected += ownerFee;
    }

    /**
    * @dev Swaps a specified amount of ERC20 tokens for ETH
    *
    * @param DEX The address of the DEX to swap on
    * @param token The address of the ERC-20 token to swap
    * @param amountIn The amount of the token to swap
    * @param amountOutMin The minimum amount of ETH to receive from the swap
    */
    function swapTokenForETH(
        address DEX,
        address token,
        uint amountIn,
        uint amountOutMin
    ) external nonReentrant {
        // Check for valid inputs
        require(DEX != address(0), "Zero Address for DEX");
        require(token != address(0), "Zero Address for token");
        require(amountIn > 0, "Zero Value for amountIn");
        require(amountOutMin > 0, "Zero Value for amountOutMin");

        // Swap with the right DEX version
        // uint8 version = _getUniswapVersion(DEX);
        // if (version == 3) {
        //     swapTokenForETHV3(DEX, token, amountIn);
        // } else if (version == 2) {
            swapTokenForETHV2(DEX, token, amountIn);
        // } else {
        //     revert("Unsupported DEX");
        // }

        // Check the amount of output tokens received from the swap
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);

        // Handle the fees and send the rest to the sender
        (uint systemFee, uint ownerFee) = getFees(amountOut);
        _sendETH(systemFeeReceiver, systemFee);
        _sendETH(ownerFeeReceiver, ownerFee);
        _sendETH(msg.sender, amountOut - (systemFee + ownerFee));

        // Update counters
        swapTokenForETHCount++;
        systemFeesCollected += systemFee;
        ownerFeesCollected += ownerFee;
    }

    /**
    * @dev Swaps a specified amount of ERC20 tokens for ERC20 tokens
    *
    * @param DEX The address of the Uniswap DEX contract
    * @param tokenIn The address of the input token
    * @param tokenOut The address of the output token
    * @param amountIn The amount of input tokens to swap
    * @param amountOutMin The minimum amount of output tokens to receive in the swap
    */
    function swapTokenForToken(address DEX, address tokenIn, address tokenOut, uint amountIn, uint amountOutMin) external nonReentrant {
        // Check for valid inputs
        require(DEX != address(0), "Zero Address for DEX");
        require(tokenIn != address(0), "Zero Address for tokenIn");
        require(tokenOut != address(0), "Zero Address for tokenOut");
        require(amountIn > 0, "Zero Value for amountIn");
        require(amountOutMin > 0, "Zero Value for amountOutMin");

        // Calculate fees
        (uint systemFee, uint ownerFee) = getFees(amountIn);
        _transferIn(msg.sender, systemFeeReceiver, tokenIn, systemFee);
        _transferIn(msg.sender, ownerFeeReceiver, tokenIn, ownerFee);
        uint amountInLessFees = amountIn - (systemFee + ownerFee);

        // Swap with the right DEX version
        uint amountOut = 0;
        uint8 version = getUniswapVersion(DEX);
        if (version == 3) {
            amountOut = swapTokenForTokenV3(DEX, tokenIn, tokenOut, amountInLessFees);
        } else if (version == 2) {
            amountOut = swapTokenForTokenV2(DEX, tokenIn, tokenOut, amountInLessFees);
        } else {
            revert("Unsupported DEX");
        }

        // Check the amount of output tokens received from the swap
        require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");

        // Update counters
        swapTokenForTokenCount++;
        systemFeesCollected += systemFee;
        ownerFeesCollected += ownerFee;
    }

    /** Internal Functions **/

    /**
    * @dev Swaps a given amount of ETH for a specified token using a Uniswap v3 DEX
    *
    * @param token The address of the token to receive in the swap
    * @param DEX The address of the Uniswap v3 DEX to use for the swap
    * @param amountIn The amount of ETH to swap
    * @param amountOutMin The minimum amount of the output token to receive in the swap
    */
    function swapETHForTokenV3(address DEX, address token, uint amountIn, uint amountOutMin) private {
        ISwapRouter router = ISwapRouter(DEX);

        // Define swap parameters as an `ExactInputSingleParams` struct
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH, // Input token is WETH
            tokenOut: token, // Output token is the specified token
            fee: feeTierV3, // Fee tier used for the swap
            recipient: msg.sender, // Recipient of the output tokens
            deadline: block.timestamp + 300, // Deadline for the swap transaction
            amountIn: amountIn, // Amount of input token to swap
            amountOutMinimum: amountOutMin, // Minimum amount of output token to receive
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute the swap using the `exactInputSingle` function of the Uniswap v3 router contract
        router.exactInputSingle{value: amountIn}(params);
    }

    /**
    * @dev Swaps a given amount of ETH for a specified token using a Uniswap v2 DEX
    *
    * @param DEX The address of the Uniswap v2 DEX to use for the swap
    * @param token The address of the token to receive in the swap
    * @param amountIn The amount of ETH to swap
    * @param amountOutMin The minimum amount of the output token to receive in the swap
    */
    function swapETHForTokenV2(
        address DEX, 
        address token, 
        uint amountIn, 
        uint amountOutMin
    ) private {
        // Instantiate the Uniswap v2 router
        IUniswapV2Router02 router = IUniswapV2Router02(DEX);

        // Define the swap path as WETH to the specified token
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;

        // Execute the swap using the router's swapExactETHForTokensSupportingFeeOnTransferTokens function
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountIn
        }(
            amountOutMin, // minimum amount of output token to receive
            path, // swap path
            msg.sender, // recipient address
            block.timestamp + 300 // deadline for the swap transaction
        );

        // Clear the memory used for the swap path
        delete path;
    }

    /**
    * @dev Swaps a given amount of a token for ETH on a Uniswap v3 decentralized exchange
    *
    * @param DEX The address of the Uniswap v3 pool contract
    * @param token The address of the token to be swapped
    * @param amountIn The amount of tokens to be swapped
    */
    function swapTokenForETHV3(
        address DEX, 
        address token, 
        uint amountIn
    ) private {
        // Instantiate the Uniswap v3 pool contract
        IUniswapV3Pool pool = IUniswapV3Pool(DEX);

        // Get the addresses of the two tokens in the pool
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Determine the direction of the swap: true for token0 to token1, false for token1 to token0
        bool zeroForOne;
        if (token == token0) {
            zeroForOne = true;
        } else if (token == token1) {
            zeroForOne = false;
        } else {
            revert("Invalid token input for pool");
        }

        // Get the current state of the pool
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Transfer the tokens to the pool contract
        _transferIn(msg.sender, address(pool), token, amountIn);

        // Execute the swap
        pool.swap(
            address(this),  // recipient of the ETH
            zeroForOne,  // directionality of the swap
            int256(amountIn),  // amount of tokens to swap
            sqrtPriceX96,  // limit the price of the swap
            new bytes(0)  // optional data to include with the swap
        );
    }

    /**
    * @dev Swaps an ERC20 token for ETH using Uniswap V2
    *
    * @param DEX The address of the Uniswap V2 router contract
    * @param token The address of the ERC20 token to swap
    * @param amountIn The amount of the ERC20 token to swap
    */
    function swapTokenForETHV2(address DEX, address token, uint amountIn) private {
        // Get the Uniswap V2 pool for the given token and WETH
        IPairV2 pool = IPairV2(IUniswapV2Factory(IUniswapV2Router02(DEX).factory()).getPair(token, WETH));

        // Transfer the tokens to the pool contract
        _transferIn(msg.sender, address(pool), token, amountIn);

        // Define a memory struct for swap-related variables
        SwapVariables memory swapVars;

        // The input token is the token being swapped, the output token is WETH
        (swapVars.input, swapVars.output) = (token, WETH);

        // Sort the input and output tokens for consistency
        (swapVars.token0,) = sortTokens(swapVars.input, swapVars.output);

        // Get the current reserves of the input and output tokens in the pool
        (uint reserve0, uint reserve1,) = pool.getReserves();

        // Determine which reserve value corresponds to the input token and which corresponds to the output token
        (uint reserveInput, uint reserveOutput) = swapVars.input == swapVars.token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // Calculate the amount of input tokens used in the swap
        swapVars.amountInput = IERC20(swapVars.input).balanceOf(address(pool)) - reserveInput;

        // Calculate the amount of output tokens to receive from the swap
        swapVars.amountOutput = getAmountOut(swapVars.amountInput, reserveInput, reserveOutput);

        // Set amount0Out and amount1Out for the swap function
        uint amount0Out;
        uint amount1Out;
        if (swapVars.input == swapVars.token0) {
            amount0Out = 0;
            amount1Out = swapVars.amountOutput;
        } else {
            amount0Out = swapVars.amountOutput;
            amount1Out = 0;
        }

        // Make the swap
        pool.swap(
            amount0Out, 
            amount1Out, 
            address(this),
            new bytes(0)
        );
    }

    /**
    * @dev Swaps a given amount of an input token for an output token using a Uniswap v3 DEX
    *
    * @param DEX The address of the Uniswap v3 DEX to use for the swap
    * @param tokenIn The address of the input token
    * @param tokenOut The address of the output token
    * @param amountIn The amount of the input token to swap
    * @return amountOut The amount of the output token received from the swap
    */
    function swapTokenForTokenV3(
        address DEX,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) private returns (uint amountOut) {
        // Get the Uniswap v3 pool for the input and output tokens
        IUniswapV3Pool pool = IUniswapV3Pool(DEX);
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Determine the direction of the swap (token0 to token1 or token1 to token0)
        bool zeroForOne;
        if (tokenIn == token0) {
            zeroForOne = true;
        } else if (tokenIn == token1) {
            zeroForOne = false;
        } else {
            revert("Invalid token input for pool");
        }

        // Get the current state of the pool
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        // uint32 secondsIn = 10;
        // uint256 price = IUniswapV3PriceOracle(uniswapV3PriceOracle).estimateAmountOut(token, uint128(amountIn), secondsIn);

        // Transfer the input tokens into the liquidity pool
        _transferIn(msg.sender, address(pool), tokenIn, amountIn);

        // Make the swap
        uint before = IERC20(tokenOut).balanceOf(msg.sender);
        pool.swap(
            address(this), // recipient
            zeroForOne, // directionality
            (zeroForOne) ? int256(amountIn) : int256(amountIn) * -1, // amountSpecified
            sqrtPriceX96, // sqrtPriceLimitX96
            new bytes(0)
        );

        // Return the amount of the output token received from the swap
        return IERC20(tokenOut).balanceOf(msg.sender) - before;
    }


    /**
    * @dev Swaps a given amount of an input token for an output token using a Uniswap v2 DEX
    *
    * @param DEX The address of the Uniswap v2 DEX to use for the swap
    * @param tokenIn The address of the input token
    * @param tokenOut The address of the output token
    * @param amountIn The amount of the input token to swap
    * @return amountOut The amount of the output token received from the swap
    */
    function swapTokenForTokenV2(
        address DEX, 
        address tokenIn, 
        address tokenOut, 
        uint amountIn
    ) private returns (uint amountOut) {
        // Get the Uniswap v2 pair for the input and output tokens
        IPairV2 pair = IPairV2(IUniswapV2Factory(IUniswapV2Router02(DEX).factory()).getPair(tokenIn, tokenOut));
        
        // Transfer the input tokens into the liquidity pool
        _transferIn(msg.sender, address(pair), tokenIn, amountIn);

        // Define a memory struct for swap-related variables
        SwapVariables memory swapVars;

        // The input token is the token being swapped, the output token is the token to receive from the swap
        (swapVars.input, swapVars.output) = (tokenIn, tokenOut);

        // Sort the input and output tokens for consistency
        (swapVars.token0,) = sortTokens(swapVars.input, swapVars.output);

        // Get the current reserves of the input and output tokens in the pair
        (uint reserve0, uint reserve1,) = pair.getReserves();

        // Determine which reserve value corresponds to the input token and which corresponds to the output token
        (uint reserveInput, uint reserveOutput) = swapVars.input == swapVars.token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // Calculate the amount of input tokens used in the swap
        swapVars.amountInput = IERC20(swapVars.input).balanceOf(address(pair)) - reserveInput;

        // Calculate the amount of output tokens to receive from the swap
        swapVars.amountOutput = getAmountOut(swapVars.amountInput, reserveInput, reserveOutput);

        // Set amount0Out and amount1Out for the swap function
        uint amount0Out;
        uint amount1Out;
        if (swapVars.input == swapVars.token0) {
            // The input token is token0, so the amount of token1 (output token) to receive is `amount1Out`
            amount0Out = 0;
            amount1Out = swapVars.amountOutput;
        } else {
            // The input token is token1, so the amount of token0 (output token) to receive is `amount0Out`
            amount0Out = swapVars.amountOutput;
            amount1Out = 0;
        }

        // Get the amount of the output token held by the user before the swap
        uint before = IERC20(tokenOut).balanceOf(msg.sender);

        // Make the swap.
        pair.swap(
            amount0Out, 
            amount1Out, 
            msg.sender, // The recipient of the output tokens
            new bytes(0) // No
        );

        // Return the amount of the output token received from the swap
        return IERC20(tokenOut).balanceOf(msg.sender) - before;
    }

    /**
    * @dev Given an address for a DEX, determines its Uniswap version (if any)
    *
    * @param DEX The address of the DEX
    * @return The Uniswap version of the DEX (2, 3) or 0 if it's not a Uniswap DEX
    */
    function getUniswapVersion(address DEX) public view returns (uint8) {
        if (isUniswapV2(DEX)) {
            return 2;
        } else if (isUniswapV3(DEX)) {
            return 3;
        } else {
            return 0;
        }
    }

    /**
    * @dev Checks if the given DEX address supports Uniswap v2 interface
    *
    * @param DEX The address of the DEX
    * @return true if the DEX supports Uniswap v2 interface, false otherwise
    */
    function isUniswapV2(address DEX) internal view returns (bool) {
        bytes4 uniswapV2InterfaceId = 0x38ed1739; // Interface ID for IUniswapV2Router01 (swapExactTokensForTokens)
        (bool success, bytes memory result) = DEX.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, uniswapV2InterfaceId));
        return success && abi.decode(result, (bool));
    }

    /**
    * @dev Checks if the given DEX address supports Uniswap v3 interface
    *
    * @param DEX The address of the DEX
    * @return true if the DEX supports Uniswap v3 interface, false otherwise
    */
    function isUniswapV3(address DEX) internal view returns (bool) {
        bytes4 uniswapV3InterfaceId = 0x58a21736; // Interface ID for IUniswapV3Router (exactInput)
        (bool success, bytes memory result) = DEX.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, uniswapV3InterfaceId));
        return success && abi.decode(result, (bool));
    }

    /**
    * @dev Given an input amount, calculates the output amount based on the reserves of two ERC20 tokens in a liquidity pool
    *
    * @param amountIn The input amount
    * @param reserveIn The reserve amount of the input token
    * @param reserveOut The reserve amount of the output token
    * @return amountOut The output amount, calculated based on the input amount and the reserve amounts of the tokens
    */
    function getAmountOut(
        uint amountIn, 
        uint reserveIn, 
        uint reserveOut
    ) internal view returns (uint amountOut) {
        // Ensure that the input amount is greater than zero
        require(amountIn > 0, 'PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        
        // Ensure that both reserves are greater than zero
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        
        // Calculate the input amount with the fee deducted
        uint amountInWithFee = amountIn * (feeDenominator - (ownerFeeNumerator + systemFeeNumerator));
        
        // Calculate the numerator of the output amount equation
        uint numerator = amountInWithFee * (reserveOut);
        
        // Calculate the denominator of the output amount equation
        uint denominator = (reserveIn * feeDenominator) - amountInWithFee;
        
        // Calculate the output amount based on the input amount and the reserve amounts of the tokens
        return numerator / denominator;
    }

    /**
    * @dev Given two ERC20 tokens, returns them in the order that they should be sorted in for use in other functions
    *
    * @param tokenA The first token address
    * @param tokenB The second token address
    * @return token0 The address of the first token, sorted alphabetically
    * @return token1 The address of the second token, sorted alphabetically
    */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        // Ensure that the two token addresses are not identical
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        
        // Sort the two token addresses alphabetically and return them
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        // Ensure that the first token address is not the zero address
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    /**
    * @dev Calculates the fees to be deducted from a given amount, based on the system fee and owner fee percentages
    *
    * @param amount The amount to calculate fees for
    * @return systemFee_ The system fee, calculated as a fraction of the amount
    * @return ownerFee_ The owner fee, calculated as a fraction of the amount
    */
    function getFees(uint amount) public view returns (uint systemFee_, uint ownerFee_) {
        // Calculate the system fee as a fraction of the amount, based on the systemFeeNumerator and feeDenominator
        uint systemFee = (amount * systemFeeNumerator) / feeDenominator;
        
        // Calculate the owner fee as a fraction of the amount, based on the ownerFeeNumerator and feeDenominator
        uint ownerFee = (amount * ownerFeeNumerator) / feeDenominator;
        
        // Return the system fee and owner fee as a tuple
        return (systemFee, ownerFee);
    }

    /**
    * @dev Sends a specified amount of Ether (ETH) from the contract to the specified receiver's address
    *
    * @param receiver_ The address of the receiver of the ETH
    * @param amount The amount of ETH to be sent
    */
    function _sendETH(address receiver_, uint amount) internal {
        (bool s,) = payable(receiver_).call{value: amount}("");
        require(s, 'Failure On ETH Transfer');
    }

    /**
    * @dev Transfers a specified amount of a given ERC20 token from one user to another user, and returns the amount of tokens that were actually received
    *
    * @param fromUser The address of the user who is sending the tokens
    * @param toUser The address of the user who is receiving the tokens
    * @param token The address of the ERC20 token being transferred
    * @param amount The amount of tokens being transferred
    * @return The amount of tokens that the recipient actually received
    */
    function _transferIn(address fromUser, address toUser, address token, uint amount) internal returns (uint) {
        // Check the allowance for the specified token
        uint allowance = IERC20(token).allowance(fromUser, address(this));
        require(allowance >= amount, "Insufficient Allowance");

        // Get the recipient's balance before the transfer
        uint before = IERC20(token).balanceOf(toUser);
        
        // Attempt to transfer the specified amount of tokens from the sender to the recipient
        bool s = IERC20(token).transferFrom(fromUser, toUser, amount);
        
        // Calculate the amount of tokens that the recipient actually received
        uint received = IERC20(token).balanceOf(toUser) - before;
        
        // Ensure that the transfer was successful and that the recipient received the expected amount of tokens
        require(s && (received > 0) && (received <= amount), "Error On Transfer From");
        
        // Return the amount of tokens that the recipient actually received
        return received;
    }

    receive() external payable {}
}