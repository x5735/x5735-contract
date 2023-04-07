// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IOracle.sol";
import "./ABDKMath64x64.sol";
import "./Constants.sol";

contract Nucleus is Ownable, ReentrancyGuard {

    uint256 public constant CLAIM_TIME = 1680084000;

    using ABDKMath64x64 for uint256;
    using SafeERC20 for IERC20;

    IOracle public oracle;

    event UpdateOracle(address oldAddress, address newAddress);
    event Claim(address receiver, bytes32 key, uint256 sctAmount, uint256 tokenAmount);

    modifier reachTime() {
        require(block.timestamp >= CLAIM_TIME, "not reached time");
        _;
    }

    receive() external payable {}

    constructor(address _oracle) {
        oracle = IOracle(_oracle);
    }

    function setOracleAddress(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "invalid oracle address");
        oracle = IOracle(_newOracle);
        emit UpdateOracle(address(oracle), _newOracle);
    }

    // approve
    function claim(bytes32 key, uint256 amount) external payable nonReentrant reachTime {
        require(key != Key.SCT, "can not use SCT"); 

         (,uint216 sctRate, address sct, bool sctValid) = oracle.getRatesDetail(Key.SCT);    
        require(sctValid, "SCT rates is not active");

        require(IERC20(sct).balanceOf(address(this)) >= amount, "not enough sct token to claim");  

        (, uint216 rate, address token, bool valid) = oracle.getRatesDetail(key);
        if (key != Key.BNB) require(token != address(0), "invalid token address");
        require(valid, "rates not active");

        uint256 costAmount = cal(amount, sctRate, rate);
        require(costAmount > 0, "cost amount must > 0");
        
        if (key == Key.BNB) {
            require(msg.value >= costAmount, "not enough BNB");
            uint256 remain = msg.value - costAmount;
            if (remain > 0) {
                Address.sendValue(payable(msg.sender), remain);
            }
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), costAmount);
        }

        IERC20(sct).safeTransfer(msg.sender, amount);
        emit Claim(msg.sender, key, amount, costAmount);
    }

    function release(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount, "not enough token to release");    
        IERC20(token).safeTransfer(owner(), amount);
    }

    function releaseBNB() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    function cal(uint256 amount, uint216 sctRate, uint216 rate) public pure returns (uint256) {
        uint256 costAmount = ABDKMath64x64.mulu(uint256(sctRate).divu(rate), amount);
        return costAmount;
    }

}