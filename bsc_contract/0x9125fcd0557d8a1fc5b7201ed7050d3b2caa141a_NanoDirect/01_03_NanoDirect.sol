//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IUniswapV2Router02.sol";
import "./IERC20.sol";

contract NanoDirect {
    
    IUniswapV2Router02 constant router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    address[] path;
    
    address creator;
    
    constructor() {
        creator = msg.sender;
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = 0xB15488af39bD1de209D501672a293Bcd05f82Ab4;
    }
    
    function withdraw(address token, address receiver) external {
        require(msg.sender == creator);
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0);
        IERC20(token).transfer(receiver, bal);
    }
    
    // Swap For Enhance
    receive() external payable {
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            msg.sender,
            block.timestamp + 30
        );
    }
    
}