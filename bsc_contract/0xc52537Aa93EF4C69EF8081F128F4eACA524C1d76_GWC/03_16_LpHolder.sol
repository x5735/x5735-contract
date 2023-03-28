// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract LpHolder{

    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    Interest lpInterest;
    address private _lastHolder;
    
    struct Interest{
        uint256 index;
        uint256 cumulative;
        uint256 sendCount;
        EnumerableSet.AddressSet lpHolder;
    }

    constructor(uint256 sendCount_) {
        lpInterest.sendCount = sendCount_;
    }

    function getUniswapV2Pair() public view virtual returns(IUniswapV2Pair);

    function _isUniswapPair(address addr) internal view returns (bool) {
        return addr == address(getUniswapV2Pair());
    }

    function _isLiquidity(address from, address to) internal view returns(bool isAdd,bool isDel){
        address token0 = getUniswapV2Pair().token0();
        address token1 = getUniswapV2Pair().token1();
        address usdtAddr; uint usdtNum;
        (uint r0, uint r1,) = getUniswapV2Pair().getReserves();
        if(token0 != address(this)){
            usdtNum = r0;
            usdtAddr = token0;
        }
        if(token1 != address(this)){
          usdtNum = r1;
          usdtAddr = token1;
        }
        uint usdtNumNew = IERC20(usdtAddr).balanceOf(address(getUniswapV2Pair()));
        isAdd = _isUniswapPair(to) && usdtNumNew > usdtNum;
        isDel = _isUniswapPair(from) && usdtNumNew < usdtNum;
    }

    function _addTokenHolder(address from, address to) internal {
        if (_lastHolder != address(0)) {
            uint256 balance = getUniswapV2Pair().balanceOf(_lastHolder);
            if(balance > 0) {
                lpInterest.lpHolder.add(_lastHolder);
            } else {
                lpInterest.lpHolder.remove(_lastHolder);
            }   
            _lastHolder = address(0);
        }

        if (_isUniswapPair(from) && !to.isContract()) _lastHolder = to;
        if (_isUniswapPair(to) && !from.isContract()) _lastHolder = from;
    }

    function _lpHolderReward(uint256 amount, function(address, address, uint256) transfer) internal returns(bool) {
        if (++lpInterest.cumulative < lpInterest.sendCount || IERC20(address(this)).balanceOf(address(this)) < amount) return false;
        lpInterest.cumulative = 0;
        uint256 _sendCount = lpInterest.sendCount;
        uint256 lpHolderLength = lpInterest.lpHolder.length();
        if (lpHolderLength <= lpInterest.sendCount) {
            _sendCount = lpHolderLength;
            lpInterest.index = 0;
        }
        uint256 lpTotal = getUniswapV2Pair().totalSupply();
        uint256 index = lpInterest.index; 
        address shareholder; 
        for (uint256 i; i < _sendCount; i++){
            if (index >= lpHolderLength) index = 0;
            shareholder = lpInterest.lpHolder.at(index);
            transfer(address(this), shareholder, (amount * getUniswapV2Pair().balanceOf(shareholder) / lpTotal));
            ++index;
        } 
        lpInterest.index = index;
        return true;
    }




    

}