/**
 *Submitted for verification at BscScan.com on 2023-03-30
*/

pragma solidity ^0.8.0;

interface IBUSD {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BUSDExchange {
    IBUSD busd;
    mapping(address => uint256) public allowances;
    
    constructor(address _busdAddress) {
        busd = IBUSD(_busdAddress);
    }
    
    function approveBUSD(uint256 _amount) external {
        allowances[msg.sender] = _amount;
        busd.approve(address(this), _amount);
    }
    
    function exchangeBUSD(address _recipient, uint256 _amount) external {
        require(busd.balanceOf(msg.sender) >= _amount, "Insufficient BUSD balance");
        require(allowances[msg.sender] >= _amount, "Insufficient BUSD allowance");
        require(busd.transferFrom(msg.sender, _recipient, _amount), "BUSD transfer failed");
    }
}