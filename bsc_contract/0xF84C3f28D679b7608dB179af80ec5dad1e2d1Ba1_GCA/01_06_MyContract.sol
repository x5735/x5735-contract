pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenReceiver {
    constructor(address token) {
        IERC20(token).approve(msg.sender, ~uint256(0));
    }
}

contract GCA is ERC20, Ownable {

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;

    address constant public ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant public USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public lpWallet = 0xfd123EDf3e3cc4A248752eFe1a612b24FD1A0286;
    address public marketingWallet = 0x4ab23D913A436153737ab8E8939fC014Fa9061e1;
    address public feeDistributor = 0x4ab23D913A436153737ab8E8939fC014Fa9061e1;
    uint256 public feeToStarTwo;
    uint256 public feeToStarThree;

    TokenReceiver public tokenReceiver;

    uint256 public numTokensSellToSwap = 100000 * 1e18;
    
    uint256 public _buyStarTwoFee = 2;
    uint256 public _buyStartThreeFee = 2;
    uint256 public _buyLpFee = 1;
    uint256 public _buyBackFee = 5;
    
    uint256 public _sellStarTwoFee = 2;
    uint256 public _sellStartThreeFee = 2;
    uint256 public _sellLpFee = 1;
    uint256 public _sellBackFee = 5;

    uint256 public _transferFee = 30;

    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;

    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() ERC20("GCAFINANCE", "GCA") {
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(ROUTER);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), USDT);

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        tokenReceiver = new TokenReceiver(USDT);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(marketingWallet, true);
        excludeFromFees(lpWallet, true);
        excludeFromFees(feeDistributor, true);

        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        IERC20(USDT).approve(address(uniswapV2Router), ~uint256(0));

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(lpWallet, 100000000 * 1e18);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
    }

    function setBuyStarTwoFee(uint256 buyStarTwoFee) external onlyOwner {
        _buyStarTwoFee = buyStarTwoFee;
    }

    function setBuyStartThreeFee(uint256 buyStartThreeFee) external onlyOwner {
        _buyStartThreeFee = buyStartThreeFee;
    }

    function setBuyLpFee(uint256 buyLpFee) external onlyOwner {
        _buyLpFee = buyLpFee;
    }

    function setBuyBackFee(uint256 buyBackFee) external onlyOwner {
        _buyBackFee = buyBackFee;
    }

    function setSellStarTwoFee(uint256 sellStarTwoFee) external onlyOwner {
        _sellStarTwoFee = sellStarTwoFee;
    }

    function setSellStartThreeFee(uint256 sellStartThreeFee) external onlyOwner {
        _sellStartThreeFee = sellStartThreeFee;
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

    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        marketingWallet = _marketingWallet;
    }

    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        feeDistributor = _feeDistributor;
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
            uint feeToThis;
            uint feeToStarTwoWallet;
            uint feeToStarThreeWallet;
            uint originalAmount = amount;
            if(sender == uniswapV2Pair) { //buy
                feeToThis = _buyLpFee + _buyBackFee;
                feeToStarTwoWallet = _buyStarTwoFee;
                feeToStarThreeWallet = _buyStartThreeFee;
            } else if (recipient == uniswapV2Pair) {
                feeToThis = _sellLpFee + _sellBackFee;
                feeToStarTwoWallet = _sellStarTwoFee;
                feeToStarThreeWallet = _sellStartThreeFee;
            } else {
                uint burnFee = amount * _transferFee / 100;
                if (burnFee > 0) {
                    super._transfer(sender, address(0xdead), burnFee);
                    amount -= burnFee;
                }
            }

            if(feeToThis > 0) {
                uint256 feeAmount = originalAmount * feeToThis / 100;
                super._transfer(sender, address(this), feeAmount);
                amount -= feeAmount;
            }
            if(feeToStarTwoWallet > 0) {
                uint256 feeAmount = originalAmount * feeToStarTwoWallet / 100;
                super._transfer(sender, feeDistributor, feeAmount);
                feeToStarTwo += feeAmount;
                amount -= feeAmount;
            }
            if(feeToStarThreeWallet > 0) {
                uint256 feeAmount = originalAmount * feeToStarThreeWallet / 100;
                super._transfer(sender, feeDistributor, feeAmount);
                feeToStarThree += feeAmount;
                amount -= feeAmount;
            }
        }
        super._transfer(sender, recipient, amount);
    }

    function swapAndDividend(uint256 tokenAmount) private lockTheSwap {
        uint totalBuyShare = _buyLpFee + _buyBackFee;
        uint totalSellShare = _sellLpFee + _sellBackFee;

        uint amountToLp = tokenAmount * (_buyLpFee + _sellLpFee)  / (totalBuyShare + totalSellShare);
        swapAndLiquify(amountToLp);

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount - amountToLp,
            0, // accept any amount of USDT
            path,
            marketingWallet,
            block.timestamp
        );
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
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
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
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}