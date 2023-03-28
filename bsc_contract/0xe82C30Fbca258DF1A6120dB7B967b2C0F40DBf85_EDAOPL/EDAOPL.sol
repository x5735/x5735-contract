/**
 *Submitted for verification at BscScan.com on 2023-03-28
*/

pragma solidity ^0.6.0;

// SPDX-License-Identifier: Unlicensed

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function decimals() external pure returns (uint8);
}

// 基类合约
contract Base {
    // address USDT = 0xCd23106Bd8C4e29aC995BAE153cEF4343FdB6836;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;

    address _owner;
    address _Manager;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Permission denied");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == _Manager, "Permission denied");
        _;
    }

    function transferManagership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        _Manager = newOwner;
    }


    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        _owner = newOwner;
    }

    receive() external payable {}
}

contract EDAOPL is Base {
    uint256 public totalPlayCount;

  
    constructor() public {
        _owner = msg.sender;
        _Manager = msg.sender;
    }

    function USDTPL(address[] calldata addres, uint256[] calldata price)
        public
        payable
        onlyManager
    {
        for (uint256 i = 0; i < addres.length; i++) {
            address add = addres[i];
            IERC20(USDT).transferFrom(
                address(msg.sender),
                address(add),
                price[i]
            );
        
        }
    }
 
}