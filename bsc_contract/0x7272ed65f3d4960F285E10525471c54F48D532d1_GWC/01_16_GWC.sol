// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Brothers.sol";
import "./LpHolder.sol";
import "./Swap.sol";

contract GWC is ERC20Burnable, Brothers, LpHolder, Swap {

    bool private _isLpHolderReward;
    uint256 maxSupply;
    address scavenger;
    
    IUniswapV2Pair iUniswapV2Pair;
    IUniswapV2Router02 iUniswapV2Router02;
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    mapping(address => bool) public blacklist;
    mapping(address => bool) public miner;

    constructor(
        string memory name_, 
        string memory symbol_, 
        uint amount, 
        IUniswapV2Router02 iUniswapV2Router02_, 
        address scavenger_, 
        address tokenReceiver, 
        address usdt,
        uint256 sendCount
    ) ERC20(name_, symbol_) LpHolder(sendCount) Swap(tokenReceiver) {
        _mint(msg.sender, 10 ** decimals() * amount);
        maxSupply = 10 ** decimals() * 1000000000;
        iUniswapV2Router02 = iUniswapV2Router02_;
        scavenger = scavenger_;
        iUniswapV2Pair = IUniswapV2Pair(IUniswapV2Factory(iUniswapV2Router02.factory()).createPair(address(this), usdt));
    }

    function getUniswapV2Pair() public view override(LpHolder, Swap) returns(IUniswapV2Pair) {
        return iUniswapV2Pair;
    }

    function getUniswapV2Router02() public view override returns(IUniswapV2Router02) {
        return iUniswapV2Router02;
    }

    function _approve(address owner, address spender, uint256 amount) internal override(ERC20, Swap) {
        return ERC20._approve(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!blacklist[from], "is blacklist");
        if ( address(this) == from || address(this) == to) {
            super._transfer(from, to, amount);
            return;
        }
        Brothers._addBrother(from, to);
        if ((!LpHolder._isUniswapPair(from) && !LpHolder._isUniswapPair(to))) {
            super._transfer(from, to, amount);
            return;
        }
        LpHolder._addTokenHolder(from, to);

        (bool isAdd,bool isDel) = LpHolder._isLiquidity(from, to);
        if (isAdd || isDel) {
            super._transfer(from, to, amount);
            return;
        }
        if(LpHolder._isUniswapPair(to)) amount = amount * 9999 / 10000;
        uint256 fee = amount / 100;
        
        _burn(from, fee);
        amount -= fee;
        
        uint256 remain = Brothers._BrothersReward(10, from, to, fee, super._transfer);
        if (remain > 0) super._transfer(from, scavenger, remain);
        amount -= fee;

        super._transfer(from, address(this), fee + fee);
        amount -= (fee + fee);
        Swap._addPool(fee);
        if (_isLpHolderReward) {
            Swap._addLiquidity();
            _isLpHolderReward = false;
        }
        
        _isLpHolderReward = LpHolder._lpHolderReward(ERC20.balanceOf(address(this)) - Swap.backPool, super._transfer);
        super._transfer(from, to, amount);
    }

    function addBlacklist(address user) public onlyOwner {
        blacklist[user] = true;
    }

    function removeBlacklist(address user) public onlyOwner {
        blacklist[user] = false;
    }

    function addMiner(address miner_) public onlyOwner {
        miner[miner_] = true;
    }

    
    function mint(address _to, uint256 _amount) public returns (bool) {
        if(!miner[_msgSender()] ||_amount + totalSupply() > maxSupply) {
            return false;
        }

        _mint(_to, _amount);
        return true;
    }
}