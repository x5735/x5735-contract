pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenReceiver {
    constructor(address token) {
        IERC20(token).approve(msg.sender, ~uint256(0));
    }
}

contract GCB is ERC20, Ownable {

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;

    address constant public ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant public USDT = 0x55d398326f99059fF775485246999027B3197955;

    address public lpWallet = 0xfd123EDf3e3cc4A248752eFe1a612b24FD1A0286;
    address public marketingWallet5 = 0x7933D063ff2E5036BC8DE9185a61ac125f3D82f7;
    address public marketingWallet10 = 0x9cAE435885488E6Ff882b056e8A180ECddF9a5b6;

    TokenReceiver public tokenReceiver;

    uint256 public numTokensSellToSwap = 21000 * 1e18;
    
    uint256 public _buyMarketingFee = 5;
    uint256 public _buyLpFee = 5;
    uint256 public _buyBackFee = 10;
    
    uint256 public _sellMarketingFee = 5;
    uint256 public _sellLpFee = 5;
    uint256 public _sellBackFee = 10;

    uint256 public _transferFee = 30;
    bool public _enableBuy;

    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;

    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() ERC20("GCB", "GCB") {
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(ROUTER);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), USDT);

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        tokenReceiver = new TokenReceiver(USDT);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(lpWallet, true);
        excludeFromFees(address(this), true);
        excludeFromFees(marketingWallet5, true);
        excludeFromFees(marketingWallet10, true);

        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        IERC20(USDT).approve(address(uniswapV2Router), ~uint256(0));

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(lpWallet, 21000000 * 1e18);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
    }

    function setEnableBuy(bool enableBuy) external onlyOwner {
        _enableBuy = enableBuy;
    }

    function setBuyMarketingFee(uint256 buyMarketingFee) external onlyOwner {
        _buyMarketingFee = buyMarketingFee;
    }

    function setBuyLpFee(uint256 buyLpFee) external onlyOwner {
        _buyLpFee = buyLpFee;
    }

    function setBuyBackFee(uint256 buyBackFee) external onlyOwner {
        _buyBackFee = buyBackFee;
    }

    function setSellMarketingFee(uint256 sellMarketingFee) external onlyOwner {
        _sellMarketingFee = sellMarketingFee;
    }

    function setSellLpFee(uint256 sellLpFee) external onlyOwner {
        _sellLpFee = sellLpFee;
    }
   
    function setSellBackFee(uint256 sellBackFee) external onlyOwner {
        _sellBackFee = sellBackFee;
    }

    function setTransferFee(uint256 transferFee) external onlyOwner {
        _transferFee = transferFee;
    }

    function setLpWallet(address _lpWallet) external onlyOwner {
        lpWallet = _lpWallet;
    }

    function setMarketingWallet5(address _marketingWallet5) external onlyOwner {
        marketingWallet5 = _marketingWallet5;
    }

    function setMarketingWallet10(address _marketingWallet10) external onlyOwner {
        marketingWallet10 = _marketingWallet10;
    }

    function setNumTokensSellToSwap(uint256 value) external onlyOwner {
        numTokensSellToSwap = value;
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "ERC20: transfer zero amount");

        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToSwap;

        if( overMinTokenBalance &&
            !swapping &&
            from != uniswapV2Pair
        ) {
            swapAndDividend(contractTokenBalance);
        } 

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee); 
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if(takeFee) {
            uint256 totalFee;
            (, bool isRemoveLp) = isRemoveOrAddLp(sender, recipient);
            if(sender == uniswapV2Pair) { //buy
                if (!isRemoveLp)
                    require(_enableBuy, "forbid buying");
                totalFee = _buyMarketingFee + _buyLpFee + _buyBackFee;
            } else if (recipient == uniswapV2Pair) {
                totalFee = _sellMarketingFee + _sellLpFee + _sellBackFee;
            } else {
                uint burnFee = amount * _transferFee / 100;
                if (burnFee > 0) {
                    super._transfer(sender, address(0xdead), burnFee);
                    amount -= burnFee;
                }
            }

            if(totalFee > 0) {
                uint256 feeAmount = amount * totalFee / 100;
                super._transfer(sender, address(this), feeAmount);
                amount -= feeAmount;
            }
        }
        super._transfer(sender, recipient, amount);
    }

    function isRemoveOrAddLp(address from, address to) private view returns (bool, bool) {
        address token0 = IUniswapV2Pair(uniswapV2Pair).token0();
        (uint reserve0,,) = IUniswapV2Pair(uniswapV2Pair).getReserves();
        uint balance0 = IERC20(token0).balanceOf(uniswapV2Pair);

        if (from == uniswapV2Pair && reserve0 > balance0) { // remove
            return (false, true);
        }

        if (to == uniswapV2Pair && reserve0 < balance0) { // add
            return (true, false);
        }
        return (false, false);
    }

    function swapAndDividend(uint256 tokenAmount) private lockTheSwap {
        uint totalBuyShare;
        uint amountToLp;
        uint totalSellShare = _sellMarketingFee + _sellLpFee + _sellBackFee;
        if (_enableBuy) {
            totalBuyShare = _buyMarketingFee + _buyLpFee + _buyBackFee;
            amountToLp = tokenAmount * (_buyLpFee + _sellLpFee)  / (totalBuyShare + totalSellShare);
        } else {
            amountToLp = tokenAmount * _sellLpFee / totalSellShare;
        }

        swapAndLiquify(amountToLp);

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;

        uint balanceBefore = IERC20(USDT).balanceOf(address(tokenReceiver));
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount - amountToLp,
            0, // accept any amount of USDT
            path,
            address(tokenReceiver),
            block.timestamp
        );
        uint balanceIn = IERC20(USDT).balanceOf(address(tokenReceiver)) - balanceBefore;

        uint balToMarketing5;
        uint totalLeftSellShare = _sellMarketingFee + _sellBackFee;
        if (_enableBuy) {
            uint totalLeftBuyShare = _buyMarketingFee + _buyBackFee;
            balToMarketing5 = balanceIn * (_buyMarketingFee + _sellMarketingFee) / (totalLeftBuyShare + totalLeftSellShare);
        } else {
            balToMarketing5 = balanceIn * _sellMarketingFee / (_sellMarketingFee + _sellBackFee);
        }
        IERC20(USDT).transferFrom(address(tokenReceiver), marketingWallet5, balToMarketing5);
        IERC20(USDT).transferFrom(address(tokenReceiver), marketingWallet10, balanceIn-balToMarketing5);
        

    }

    function swapAndLiquify(uint256 tokens) private {
       // split the contract balance into halves
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = IERC20(USDT).balanceOf(address(tokenReceiver));

        // swap tokens for Usdt
        swapTokensForUsdt(half); // <- this breaks the Usdt -> HATE swap when swap+liquify is triggered

        // how much Usdt did we just swap into?
        uint256 newBalance = IERC20(USDT).balanceOf(address(tokenReceiver)) - initialBalance;
        IERC20(USDT).transferFrom(address(tokenReceiver), address(this), newBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
    }

    function swapTokensForUsdt(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> usdt
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of usdt
            path,
            address(tokenReceiver),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount) private {
        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(this),
            USDT,
            tokenAmount,
            usdtAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lpWallet,
            block.timestamp
        );

    }
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
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

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}