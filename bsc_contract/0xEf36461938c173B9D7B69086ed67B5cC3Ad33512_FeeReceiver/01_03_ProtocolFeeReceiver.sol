//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";
import "./Ownable.sol";

interface IBurnableToken {
    function burn(uint256 amount) external returns (bool);
}

contract FeeReceiver is Ownable {

    address public treasury = 0x53D2351da23FC86a1aB64128Acc18dA6963EacbB;
    address private constant WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant ACCU = 0x9cb949e8c256C3EA5395bbe883E6Ee6a20Db6045;
    address private constant TRUTH = 0x55a633B3FCe52144222e468a326105Aa617CC1cc;

    address private dev0 = 0xb7EE8cb807eF7ef493B902b93E60f22D268355c1;
    address private dev1 = 0x2aB15F8e211eA475bC9275A4C2BFbC9A8130EE89;
    address private dev2 = 0xA79c73246b2878FA15Ba161EC3C340BB009407dd;
    address private dev3 = 0x962Ff5a50b148d8524ABfCfbD3A7D9057Bb8e648;

    function setTreasury(address nTreasury) external onlyOwner {
        treasury = nTreasury;
    }

    function burn(address token, uint amount) external onlyOwner {
        IBurnableToken(token).burn(amount);
    }

    function withdrawAll(address token, address to) external onlyOwner {
        withdraw(token, to, IERC20(token).balanceOf(address(this)));
    }

    function withdrawAllETH(address to) external onlyOwner {
        withdrawETH(to, address(this).balance);
    }

    function withdrawETH(address to, uint amount) public onlyOwner {
        (bool s,) = payable(to).call{value: amount}("");
        require(s);
    }

    function withdraw(address token, address to, uint amount) public onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function setDev0(address newDev) external {
        require(msg.sender == dev0, 'Only Dev');
        dev0 = newDev;
    }

    function setDev1(address newDev) external {
        require(msg.sender == dev1, 'Only Dev');
        dev1 = newDev;
    }

    function setDev2(address newDev) external {
        require(msg.sender == dev2, 'Only Dev');
        dev2 = newDev;
    }

    function setDev3(address newDev) external {
        require(msg.sender == dev3, 'Only Dev');
        dev3 = newDev;
    }

    function trigger() external {

        uint balACCU = IERC20(ACCU).balanceOf(address(this));
        uint balTRUTH = IERC20(TRUTH).balanceOf(address(this));
        uint balWETH = IERC20(WETH).balanceOf(address(this));

        if (balACCU > 0) {
            IBurnableToken(ACCU).burn(balACCU);
        }

        if (balTRUTH > 0) {
            IBurnableToken(TRUTH).burn(balTRUTH);
        }

        uint256 forTreasury = balWETH / 3;
        uint256 forEach = ( balWETH - forTreasury ) / 4;

        if (balWETH > 100) {
            IERC20(WETH).transfer(treasury, forTreasury);
            IERC20(WETH).transfer(dev0, forEach);
            IERC20(WETH).transfer(dev1, forEach);
            IERC20(WETH).transfer(dev2, forEach);
            IERC20(WETH).transfer(dev3, forEach);
        }
    }
}