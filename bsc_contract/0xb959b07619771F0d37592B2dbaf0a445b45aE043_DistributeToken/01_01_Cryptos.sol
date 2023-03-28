//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    }
contract DistributeToken{
    IERC20 cguToken;
    IERC20 USDT;
    constructor (){
        cguToken=IERC20(0x747D74dB20cc422F39ab54EDB2A3Ce21f3C98AF1);
        USDT=IERC20(0x55d398326f99059fF775485246999027B3197955);
    }

    function balanceOfUSDT() external view returns (uint256){
        return USDT.balanceOf(address(this))/10**18;
    }
    function balanceOfCguToken() external view returns (uint256){
        return cguToken.balanceOf(address(this))/10**8;
    }
}