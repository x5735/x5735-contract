// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeMath.sol";
import "./lib/contracts/libraries/TransferHelper.sol";
import "./interfaces/IERC20.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";


contract AtlasRouterUpgradable is Initializable{
    using SafeMath for uint256;

    address public uniswapV2;
    address public factory;
    address public feeCollector;
    address public owner;
    address[4] public stableCoins;
    uint256 public fees; //10000 base point

    event Initialized();
    event OwnerSet();
    event FeeCollectorSet();
    event FeesSet();
    event RouterFactorySet();

    modifier onlyOwner(){
        require(msg.sender == owner,"Not Owner");
        _;
    }

    constructor(){
        _disableInitializers();
    }

    function initialize(address _routerAddress,address _factory,address wbnb,address usdt,address busd,address usdc,address _owner,uint256 _fees)external initializer{
        uniswapV2 = _routerAddress;
        factory = _factory;
        owner = _owner;
        fees = _fees;
        stableCoins[0] = wbnb; 
        stableCoins[1] = usdt; 
        stableCoins[2] = busd; 
        stableCoins[3] = usdc; 
        emit Initialized();
    }

    function swapExactTokensForTokens(  
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external payable{
            uint256 amountInForFees = ((amountIn).mul(fees)).div(10000);
            uint256 amountInForSwap = (amountIn).sub(amountInForFees);
            uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 
            require(msg.value >= feesInEth,"etherTransfer failed");
            
            if(IERC20(path[0]).allowance(address(this),uniswapV2) < amountInForSwap){
                IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            }

            TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInForSwap);
            TransferHelper.safeTransferETH(feeCollector,feesInEth);
            IUniswapV2Router02(uniswapV2).swapExactTokensForTokens(amountInForSwap,amountOutMin,path,to,deadline);
            refundDustEth();
    }

    function swapExactETHForTokens( 
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )external payable{
        uint256 amountInForFees = ((msg.value).mul(fees)).div(10000);
        uint256 amountInForSwap = (msg.value).sub(amountInForFees);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 
        require(msg.value >= feesInEth + amountInForSwap,"etherTransfer failed");
        TransferHelper.safeTransferETH(feeCollector,feesInEth);

        (bool sucess,) = payable(uniswapV2).call{value: amountInForSwap}(abi.encodeWithSignature("swapExactETHForTokens(uint256,address[],address,uint256)",amountOutMin,path,to,deadline));
        require(sucess,"Failed to swapExactETHForTokens");
        refundDustEth();
    }


    function swapExactTokensForETH(  
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )external payable {

        uint256 amountInForFees = ((amountIn).mul(fees)).div(10000);
        uint256 amountInForSwap = (amountIn).sub(amountInForFees);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 

        require(msg.value >= feesInEth,"etherTransfer failed");

        if(IERC20(path[0]).allowance(address(this),uniswapV2) < amountInForSwap){
            IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInForSwap);
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        IUniswapV2Router02(uniswapV2).swapExactTokensForETH(amountInForSwap,amountOutMin,path,to,deadline);
        refundDustEth();
    }

    function swapTokensForExactTokens( 
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {

        uint256[] memory amount = IUniswapV2Router02(uniswapV2).getAmountsIn(amountOut, path);
        uint256 amountInForFees = ((amount[0]).mul(fees)).div(10000);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 
        require(msg.value >= feesInEth,"etherTransfer failed");

        if(IERC20(path[0]).allowance(address(this),uniswapV2) < amount[0]){
            IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }

        TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amount[0]);
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        IUniswapV2Router02(uniswapV2).swapTokensForExactTokens(amountOut,amountInMax,path,to,deadline);
        refundToken(path[0]);
        refundDustEth();

    }

    function swapTokensForExactETH( 
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        uint256[] memory amount = IUniswapV2Router02(uniswapV2).getAmountsIn(amountOut, path);
        uint256 amountInForFees = ((amount[0]).mul(fees)).div(10000);

        if(IERC20(path[0]).allowance(address(this),uniswapV2) < amount[0]){
            IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }

        TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amount[0]);

        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 
        require(msg.value >= feesInEth,"etherTransfer failed");
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        IUniswapV2Router02(uniswapV2).swapTokensForExactETH(amountOut,amountInMax,path,to,deadline);
        refundToken(path[0]);
        refundDustEth();
    }

    function swapETHForExactTokens( 
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable{

        uint256[] memory amount = IUniswapV2Router02(uniswapV2).getAmountsIn(amountOut, path);
        uint256 amountInForFees = ((amount[0]).mul(fees)).div(10000);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees);
        require(msg.value >= feesInEth + amount[0],"etherTransfer failed");
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        (bool sucess,) = payable(uniswapV2).call{value: amount[0]}(abi.encodeWithSignature("swapETHForExactTokens(uint256,address[],address,uint256)",amountOut,path,to,deadline));
        require(sucess,"Failed to swapETHForExactTokens");
        refundDustEth();
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable{
        uint256 amountInForFees = ((amountIn).mul(fees)).div(10000);
        uint256 amountInForSwap = (amountIn).sub(amountInForFees);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 

        require(msg.value >= feesInEth,"etherTransfer failed");

        if(IERC20(path[0]).allowance(address(this),uniswapV2) < amountInForSwap){
            IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInForSwap);
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        IUniswapV2Router02(uniswapV2).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountInForSwap,amountOutMin,path,to,deadline);
        refundDustEth();
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        uint256 amountInForFees = ((msg.value).mul(fees)).div(10000);
        uint256 amountInForSwap = (msg.value).sub(amountInForFees);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 

        require(msg.value >= feesInEth + amountInForSwap,"etherTransfer failed");
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        (bool sucess,) = payable(uniswapV2).call{value: amountInForSwap}(abi.encodeWithSignature("swapExactETHForTokensSupportingFeeOnTransferTokens(uint256,address[],address,uint256)",amountOutMin,path,to,deadline));
        require(sucess,"Failed to swapExactETHForTokens");
        refundDustEth();
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable{
        uint256 amountInForFees = ((amountIn).mul(fees)).div(10000);
        uint256 amountInForSwap = (amountIn).sub(amountInForFees);
        uint256 feesInEth = _getFeeInEth(path[0],amountInForFees); 

        require(msg.value >= feesInEth,"etherTransfer failed");

        if(IERC20(path[0]).allowance(address(this),uniswapV2) < amountInForSwap){
            IERC20(path[0]).approve(uniswapV2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInForSwap);
        TransferHelper.safeTransferETH(feeCollector,feesInEth);
        IUniswapV2Router02(uniswapV2).swapExactTokensForETHSupportingFeeOnTransferTokens(amountInForSwap,amountOutMin,path,to,deadline);
        refundDustEth();
    }

    function refundDustEth()internal{
        TransferHelper.safeTransferETH(msg.sender,address(this).balance);
    } 
    function refundToken(address _tokenAddress)internal{
        TransferHelper.safeTransfer(_tokenAddress,msg.sender,IERC20(_tokenAddress).balanceOf(address(this)));
    }

    function setOwner(address _newOwner)external onlyOwner{
        owner = _newOwner;
        emit OwnerSet();
    }  

    function setFees(uint256 _newFees)external onlyOwner{
        fees = _newFees;
        emit FeesSet();
    }

    function setFeesCollector(address _newFeeCollector)external onlyOwner{
        feeCollector = _newFeeCollector;
        emit FeeCollectorSet();
    }
    function setRouterFactory(address _newRouter,address _newFactory)external onlyOwner{
        require(_newRouter != address(0) && _newFactory != address(0),"Zero Address");
        uniswapV2 = _newRouter;
        factory = _newFactory;
        emit RouterFactorySet();
    }




    function _getFeeInEth(address _tokenAddress,uint256 _amount)internal view returns(uint256 _feeAmountInEth){


        for(uint256 i ;i < stableCoins.length;i++){
            if(_tokenAddress == stableCoins[0]){
                _feeAmountInEth = ((_amount).mul(fees)).div(10000);
                break;
            }
            address pairAddress = IUniswapV2Factory(factory).getPair(_tokenAddress,stableCoins[i]);
            if( ((pairAddress) != address(0)) && i==0 ){
                _feeAmountInEth = _getFeeAmountOut(_amount,pairAddress,_tokenAddress,stableCoins[i]);
                if(_feeAmountInEth != 0){
                    break;
                }
            }

            else if( ((pairAddress) != address(0)) && i!=0 ){
                uint256 tempFee = _getFeeAmountOut(_amount,pairAddress,_tokenAddress,stableCoins[i]);
                pairAddress = IUniswapV2Factory(factory).getPair(stableCoins[i],stableCoins[0]);
                _feeAmountInEth = _getFeeAmountOut(tempFee,pairAddress,_tokenAddress,stableCoins[i]);
                if(_feeAmountInEth != 0){
                    break;
                }
            }
        }
    }
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function _getFeeAmountOut(uint _amountIn,address _pairAddress,address tokenA,address tokenB) internal view returns (uint amountOut) {   
        (address token0,) = _sortTokens(tokenA, tokenB); ///////////////////////////
        (uint112 reserve0,uint112 reserve1,) = IUniswapV2Pair(_pairAddress).getReserves();
        (uint reserveIn,uint reserveOut) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // uint reserveIn = reserve0;
        // uint reserveOut = reserve1;

        uint amountInWithFee = _amountIn.mul(1000);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        
        amountOut = numerator / denominator;
    }

    function getEthAmount(address _tokenAddress,uint256 _totalAmount)internal view returns(uint256 EthAmount){
        uint256 feeInAmount = ((_totalAmount).mul(fees)).div(10000);
        EthAmount = _getFeeInEth(_tokenAddress,feeInAmount);
        EthAmount = EthAmount + ((EthAmount).mul(10)).div(1000);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[3] memory amounts)
    {
        uint256[] memory amt = IUniswapV2Router02(uniswapV2).getAmountsOut(amountIn, path);
        uint256 EthAmount = getEthAmount(path[0],amt[0]);
        amounts[0] = amt[0];
        amounts[1] = amt[1];
        amounts[2] = EthAmount;
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[3] memory amounts)
    {
        uint256[] memory amt =  IUniswapV2Router02(uniswapV2).getAmountsIn(amountOut, path);
        uint256 EthAmount = getEthAmount(path[0],amt[0]);
        amounts[0] = amt[0];
        amounts[1] = amt[1];
        amounts[2] =  EthAmount;
    }

}