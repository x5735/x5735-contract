// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ITokenPlugin is Ownable {
    
    address internal _delegate;
    
    constructor(address addr) {
        setDelegate(addr);
    }
    
    function setDelegate(address addr) public virtual onlyOwner {
        _delegate = addr;
    }

    modifier onlyDelegate() {
        require(_delegate == _msgSender(), "ERC20: invalid delegate");
        _;
    }
    
    function execute(address sender, address target, uint256 amount) public virtual onlyDelegate returns (uint256) {
        require(msg.sender == _delegate, 'ERC20: unauthorized plugin');
        return _execute(sender, target, amount);
    }
    
    function _execute(address sender, address target, uint256 amount) internal virtual returns (uint256);
}