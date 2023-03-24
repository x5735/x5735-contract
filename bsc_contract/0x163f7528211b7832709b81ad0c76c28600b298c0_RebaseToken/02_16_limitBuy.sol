// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; 
contract LimitBuy is Ownable{
    using SafeMath for uint; 
    bool public isLimit;
    struct Limit{
        uint txMax;
        uint positionMax; 
    }
    Limit public limit;
    function setLimit(uint txMax,uint positionMax,uint part) external onlyOwner { 
        limit=Limit(getPart(txMax,part),getPart(positionMax,part)); 
    } 
    function removeLimit() external onlyOwner {
        isLimit=false;
    }  
    function getPart(uint256 point,uint256 part)internal view returns(uint256){
        return IERC20(address(this)).totalSupply().mul(point).div(part);
    }
    /**
     * @dev ¼ì²éÏÞ¹º 
     */
    function _checkLimit(uint amount,uint balance) internal view{
        require(amount <= limit.txMax);
        require(balance <= limit.positionMax);
    }
}