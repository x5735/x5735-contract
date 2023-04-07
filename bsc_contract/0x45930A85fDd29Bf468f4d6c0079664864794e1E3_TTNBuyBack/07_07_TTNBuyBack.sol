pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/IDEXRouter.sol";
import "contracts/interfaces/IDEXFactory.sol";
import "contracts/interfaces/IDEXPair.sol";



contract TTNBuyBack is Ownable{

    uint256 public swapBNBAtAmount;
    uint256 public swapUSDTAtAmount;
    IERC20 public TTNToken;
    IERC20 public USDT;
    IDEXRouter public defaultDexRouter;
    address public rewardWallet;

    event TransferTokensToRewardWallet(uint256 amount);
    event LogReceiveBNB(uint256 amount);
    event LogSetRouter(address _routerAddress);
    event LogSetTTNToken(address _TTNToken);
    event LogSetRewardWallet(address _rewardWallet);
    event LogSetSwapBNBAtAmount(uint256 _swapBNBAtAmount);
    event LogSetSwapUSDTAtAmount(uint256 _swapUSDTAtAmount);
    event LogbuyBackBNB(uint256 amount);
    event LogbuyBackUSDT(uint256 amount);


    constructor(
        address _TTNToken, 
        address _USDT, 
        address _rewardWallet,
        address _routerAddress,
        uint256 _swapBNBAtAmount,
        uint256 _swapUSDTAtAmount)
    {
        TTNToken = IERC20(_TTNToken);
        USDT = IERC20(_USDT);
        swapBNBAtAmount = _swapBNBAtAmount;
        swapUSDTAtAmount = _swapUSDTAtAmount;
        rewardWallet = _rewardWallet;
        IDEXRouter _dexRouter = IDEXRouter(_routerAddress);
        defaultDexRouter = _dexRouter;
    }


    receive() external payable {
        uint256 BNBbalance = address(this).balance;
        uint256 USDTbalance = USDT.balanceOf(address(this));

        if(BNBbalance >= swapBNBAtAmount){
            buyBackBNB(BNBbalance);
            uint256 tokens = TTNToken.balanceOf(address(this));
            if(tokens > 0){
                TTNToken.transfer(rewardWallet, tokens);
                emit TransferTokensToRewardWallet(tokens);
            }
        }

        if(USDTbalance >= swapUSDTAtAmount){
            buyBackUSDT(USDTbalance);
            uint256 tokens = TTNToken.balanceOf(address(this));
            if(tokens > 0){
                TTNToken.transfer(rewardWallet, tokens);
                emit TransferTokensToRewardWallet(tokens);
            }
        }

        emit LogReceiveBNB(msg.value);
    }



    function setRouter(address _routerAddress) external onlyOwner{
        require(_routerAddress != address(defaultDexRouter), "Already set to this Value");
        require(_routerAddress != address(0), "Router cannot be address 0");
        IDEXRouter _dexRouter = IDEXRouter(_routerAddress);
        defaultDexRouter = _dexRouter;
        emit LogSetRouter(_routerAddress);
    }


    function setTTNToken(address _TTNToken) external onlyOwner{
        require(address(TTNToken) != _TTNToken, "Already set to this Value");
        require(_TTNToken != address(0), "TTNToken cannot be address 0");
       
        TTNToken = IERC20(_TTNToken);
        emit LogSetTTNToken(_TTNToken);
    }


    function setRewardWallet(address _rewardWallet) external onlyOwner{
        require(rewardWallet != _rewardWallet, "Already set to this Value");
        require(_rewardWallet != address(0), "Reward wallet cannot be address 0");
       
        rewardWallet = _rewardWallet;
        emit LogSetRewardWallet(_rewardWallet);
    }


    function setSwapBNBAtAmount(uint256 _swapBNBAtAmount) external onlyOwner{
        require(swapBNBAtAmount != _swapBNBAtAmount, "Already set to this Value");
        require(_swapBNBAtAmount != 0, "Can't be 0");
       
        swapBNBAtAmount = _swapBNBAtAmount;
        emit LogSetSwapBNBAtAmount(_swapBNBAtAmount);
    }


    function setSwapUSDTAtAmount(uint256 _swapUSDTAtAmount) external onlyOwner{
        require(swapUSDTAtAmount != _swapUSDTAtAmount, "Already set to this Value");
        require(_swapUSDTAtAmount != 0, "Can't be 0");
       
        swapUSDTAtAmount = _swapUSDTAtAmount;
        emit LogSetSwapUSDTAtAmount(_swapUSDTAtAmount);
    }


    function buyBackBNB(uint256 amount) private{
        swapEthForTokens(amount);
        emit LogbuyBackBNB(amount);
    }


    function buyBackUSDT(uint256 amount) private{
        USDT.approve(address(defaultDexRouter), amount);
        swapTokensForTokens(amount);
        emit LogbuyBackUSDT(amount);
    }


    function swapEthForTokens(uint256 ethAmount) private {
        // generate the uniswap pair path of weth -> token`
        address[] memory path = new address[](2);
        path[0] = defaultDexRouter.WETH();
        path[1] = address(TTNToken);

        // make the swap
        defaultDexRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0, // accept any amount of Tokens
            path,
            address(this),
            block.timestamp + 60
        );
    }


    function swapTokensForTokens(uint256 amount) private {
        // generate the uniswap pair path of USDT -> TTNToken`
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(TTNToken);

        // make the swap
        defaultDexRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of Tokens
            path,
            address(this),
            block.timestamp + 60
        );
    }

}