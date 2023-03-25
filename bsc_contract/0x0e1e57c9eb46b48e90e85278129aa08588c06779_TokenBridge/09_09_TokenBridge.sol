// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Extension/FeeCollector.sol";
import "../Bank/IBank.sol";

contract TokenBridge is Ownable, FeeCollector {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public srcToken;
    IERC20 public trgToken;
    IBank public bank;

    uint256 internal srcTokenDecimals;
    uint256 internal trgTokenDecimals;

    uint256 public minAmount;
    uint256 public maxAmount;
    uint256 public startBlock;
    uint256 public closeBlock;

    address public bridgeAddress;
    uint256 public bridgeSrcRatio;
    uint256 public bridgeTrgRatio;

    uint256 public vaMultiply;
    uint256 public vaDivision;
    uint256 public vaLimit;

    event StartBlockChanged(uint256 block);
    event CloseBlockChanged(uint256 block);
    event BankAddressChanged(address indexed addr);
    event BridgeAddressChanged(address indexed addr);
    event BridgeConversionChanged(uint256 srcRatio, uint256 trgRatio);
    event TokenPairChanged(address indexed srcTokenAddress, uint256 srcTokenDec, address indexed trgTokenAddress, 
        uint256 trgTokenDec);
    event Withdrawn(uint256 srcAmount);
    event Exchanged(uint256 srcAmount, uint256 trgAmount);

    constructor() {
        setBridgeAddress(0x000000000000000000000000000000000000dEaD);
        setBridgeConversion(1, 1);
    }

    function setTokenPair(IERC20 srcTokenAddress, uint256 srcTokenDec, IERC20 trgTokenAddress, uint256 trgTokenDec)
        public onlyOwner
    {
        require(address(srcToken) == address(0), 'TokenBridge: token address already set');
        require(address(trgToken) == address(0), 'TokenBridge: token address already set');
        require(address(srcTokenAddress) != address(0), 'TokenBridge: cannot set zero-address as one of the tokens');
        require(address(trgTokenAddress) != address(0), 'TokenBridge: cannot set zero-address as one of the tokens');
        require(srcTokenDec > 0, 'TokenBridge: token decimals needs to be higher than zero');
        require(trgTokenDec > 0, 'TokenBridge: token decimals needs to be higher than zero');
        srcToken = srcTokenAddress;
        trgToken = trgTokenAddress;
        srcTokenDecimals = srcTokenDec;
        trgTokenDecimals = trgTokenDec;
        emit TokenPairChanged(address(srcToken), srcTokenDecimals, address(trgToken), trgTokenDecimals);
    }
    
    function setBank(IBank _bank) public onlyOwner {
        bank = _bank;
        emit BankAddressChanged(address(bank));
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        require(startBlock == 0, 'TokenBridge: start block already set');
        require(_startBlock > 0, 'TokenBridge: start block needs to be higher than zero!');
        startBlock = _startBlock;
        emit StartBlockChanged(startBlock);
    }

    function setCloseBlock(uint256 _closeBlock) public onlyOwner {
        require(startBlock != 0, 'TokenBridge: start block needs to be set first');
        require(closeBlock == 0, 'TokenBridge: close block already set');
        require(_closeBlock > startBlock, 'TokenBridge: close block needs to be higher than start one!');
        closeBlock = _closeBlock;
        emit CloseBlockChanged(closeBlock);
    }

    function setBridgeAddress(address addr) public onlyOwner {
        bridgeAddress = addr; // by default bridge address is dead, meaning tokens are burned on bridge
        emit BridgeAddressChanged(addr);
    }

    function setBridgeConversion(uint256 srcRatio, uint256 trgRatio) public onlyOwner {
        require(srcRatio > 0 && trgRatio > 0, 'TokenBridge: conversions need to have be higher than zero!');
        bridgeSrcRatio = srcRatio; // by default bridge conversion is 1
        bridgeTrgRatio = trgRatio; // by default bridge conversion is 1
        emit BridgeConversionChanged(srcRatio, trgRatio);
    }

    function withdrawTokens() external onlyOwner {
        uint256 srcBalance = srcToken.balanceOf(address(this));
        srcToken.safeTransfer(owner(), srcBalance);
        emit Withdrawn(srcBalance);
    }

    function exchangeTokens(uint256 amount) public {
        exchangeTokens(amount, 0);
    }

    function exchangeTokens(uint256 amount, uint256 minAmountBack) public payable collectFee('exchangeTokens') {
        // amount eq to zero is allowed
        require(startBlock > 0 && block.number >= startBlock, 'TokenBridge: not started yet');
        require(closeBlock == 0 || block.number <= closeBlock, 'TokenBridge: not active anymore');
        require(amount > 0, 'TokenBridge: amount needs to be higher than zero');
        require(address(bank) != address(0), 'TokenBridge: bank needs to be set');

        uint256 srcBalance = srcToken.balanceOf(bridgeAddress);
        srcToken.safeTransferFrom(address(msg.sender), bridgeAddress, amount);
        
        uint256 srcAmount = srcToken.balanceOf(bridgeAddress) - srcBalance;
        uint256 trgAmount = estimateTokens(srcAmount);

        require(minAmountBack == 0 || minAmountBack <= trgAmount,
            'TokenBridge: exchange cancelled due to higher than expected slippage');
        
        bank.withdrawFrom(owner(), trgAmount);
        trgToken.transfer(address(msg.sender), trgAmount);

        emit Exchanged(srcAmount, trgAmount);
    }

    function estimateTokens(uint256 amount) public view returns (uint256) {
        uint256 trgAmount = amount;
        if (srcTokenDecimals < trgTokenDecimals) {
            trgAmount = trgAmount.mul(10**(trgTokenDecimals-srcTokenDecimals));
        }
        if (srcTokenDecimals > trgTokenDecimals) {
            trgAmount = trgAmount.div(10**(srcTokenDecimals-trgTokenDecimals));
        }
        return trgAmount.mul(bridgeTrgRatio).div(bridgeSrcRatio);
    }
}