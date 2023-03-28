// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Fuckies is ERC20, Pausable, Ownable {

    mapping(address => bool) public whitelisted;

    modifier isNotPaused() {
        require((!paused() || msg.sender == owner() || whitelisted[msg.sender]), "Transfer not allowed");
        _;
    }
    
    constructor() ERC20("Fuckies", "FUCKIES") {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
        lockTransfer();
    }

    function lockTransfer() public onlyOwner {
        _pause();
    }

    function unlockTransfer() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        isNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setWhitelisted(address _address, bool _newState) public onlyOwner {
        whitelisted[_address] = _newState;
    }
}