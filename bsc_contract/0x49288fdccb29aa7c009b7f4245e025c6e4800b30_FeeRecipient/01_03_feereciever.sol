//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";

interface IStable {
    function sell(uint256 tokenAmount) external returns (uint256);
    function getOwner() external view returns (address);
}

contract FeeRecipient {

    // Constant Addresses
    address public constant Safuu = 0xE5bA47fD94CB645ba4119222e34fB33F59C7CD90;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant apollo = 0x32a05625d2A25054479d0c5d661857147c34483D;

    address public constant Treasury = 0xB7ACd7DE1C8D61895d1cC9511f5f638EBA0b6065;

    // REVIVE Token
    address public immutable REVIVE;

    // PCS Router
    IUniswapV2Router02 public constant router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // Address List
    address[] private USDTToBNB = [address(USDT), BNB];
    address[] private BNBToSafuu = [BNB, Safuu];

    // Ownership should match REVIVE
    modifier onlyOwner() {
        require(msg.sender == IStable(REVIVE).getOwner(), 'Only REVIVE Owner');
        _;
    }

    constructor(address REVIVE_) {
        REVIVE = REVIVE_;
    }

    function trigger() external {
        require(msg.sender == Treasury || msg.sender == IStable(REVIVE).getOwner());

        uint256 balance = IERC20(REVIVE).balanceOf(address(this));
        if (balance <= 100) {
            return;
        }

        // sell Revive
        IStable(REVIVE).sell(balance);

        // sell balance of USDT for BNB, swap into SAFUU and Apollo
        uint USDTBal = IERC20(USDT).balanceOf(address(this));

        // USDT -> BNB
        IERC20(USDT).approve(address(router), USDTBal/3);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(USDTBal / 3, 1, USDTToBNB, address(this), block.timestamp + 100);

        // BNB -> Apollo
        (bool s,) = payable(apollo).call{value: address(this).balance}("");
        require(s, 'Failure On Apollo Purchase');

        // Send USDT To Treasury
        IERC20(USDT).transfer(Treasury, IERC20(USDT).balanceOf(address(this)));

        // Send Remaining apollo to burn wallet
        IERC20(apollo).transfer(DEAD, IERC20(apollo).balanceOf(address(this)));
        
    }


    function withdraw(address token) external onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function withdrawETH() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    receive() external payable {}

}