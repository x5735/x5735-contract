// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./VaultMSData.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IElpManager.sol";
import "../tokens/interfaces/IUSDX.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../DID/interfaces/IESBT.sol";

pragma solidity ^0.8.0;

interface IPrevVault {
    function poolAmounts(address _token) external returns (uint256);
    function tokenDecimals(address _token) external returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
}

interface ITransferSwap {
    function swap(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        uint8 flag
    ) external returns (uint256 returnAmount);

}

contract ElpTransferHelper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;


    address public prevElp;
    address public latestElp;
    address public prevElpManager;
    address public latestElpManager;
    address public prevVault;
    address public weth;
    address[] public tokens;

    address public busd;
    address public usdt;

    address public swapPool;

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }
    
    function setAddress(address _prevElp, address _latestElp, 
            address _prevElpManager, address _latestElpManager, 
            address _weth, address _prevVault) external onlyOwner{
        prevElp = _prevElp;
        latestElp = _latestElp;
        prevElpManager = _prevElpManager;
        latestElpManager = _latestElpManager;
        weth = _weth;
        prevVault = _prevVault;
    }

    function setTokens(address[] memory _tokens) external onlyOwner{
        tokens = _tokens;
    }

    function setSwapPool(address _swapPool) external onlyOwner{
        swapPool = _swapPool;
    }

    function setUSD(address _busd, address _usdt) external onlyOwner{
        busd = _busd;
        usdt = _usdt;
    }

    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }


    function swap(address _inToken, uint256 _amount, address _outToken) external{
        IERC20(_inToken).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_inToken).approve(swapPool, _amount);
        uint256 returnAmount = ITransferSwap(swapPool).swap(_inToken, _outToken, _amount, 0,0);
        IERC20(_outToken).safeTransfer(msg.sender, returnAmount);
    }


    function transferToNewPool(uint256 _amount) external { 
        address _account = msg.sender;
        IERC20(prevElp).safeTransferFrom(_account, address(this), _amount);
        IPrevVault vault = IPrevVault(prevVault);
        uint256[] memory poolAum = new  uint256[](tokens.length);
        uint256 totalAum = 0;
        for(uint8 i = 0; i < tokens.length; i++){
            uint256 price = vault.getMinPrice(tokens[i]);
            uint256 decimals = vault.tokenDecimals(tokens[i]);
            poolAum[i] = vault.poolAmounts(tokens[i]).mul(price).div(10 ** decimals);
            totalAum = totalAum.add(poolAum[i]);
        }
        if (totalAum < 1) return ;

        uint256 newElpAmount = 0;
        for(uint8 i = 0; i < tokens.length; i++){
            uint256 _elpAmount = _amount.mul(poolAum[i]).div(totalAum);
            uint256 rtnAmount = IElpManager(prevElpManager).removeLiquidity(tokens[i], _elpAmount, 0, address(this));
            
            address _buyToken = tokens[i];
            uint256 _buyAmount = rtnAmount;
            if (tokens[i] == busd){
                _buyToken = usdt;
                IERC20(busd).approve(swapPool, _amount);
                _buyAmount = ITransferSwap(swapPool).swap(busd, usdt, rtnAmount, 0,0);
            }
            IERC20(tokens[i]).approve(latestElpManager, rtnAmount);
            newElpAmount = newElpAmount.add(IElpManager(latestElpManager).addLiquidity(_buyToken, _buyAmount, 0, 0));
        }

        IERC20(latestElp).safeTransfer(_account, newElpAmount);
    }

}