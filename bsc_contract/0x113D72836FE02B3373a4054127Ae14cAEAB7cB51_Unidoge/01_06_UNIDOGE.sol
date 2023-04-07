pragma solidity 0.8.18;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Unidoge is ERC20, Ownable {

    error Blacklisted();
    error MaxWalletReached();

    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isExempt;
    mapping(address => bool) public isPair;

    uint256 public maxWallet = 1_000_000_000 * 10**18;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol){
        _mint(msg.sender, 100_000_000_000 * 10**18);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        if(!isExempt[from] && !isExempt[to]){
            if(isBlacklisted[from] || isBlacklisted[to]) revert Blacklisted();
            if(!isPair[to] && balanceOf(to) + amount > maxWallet) revert MaxWalletReached();
        }

        super._transfer(from, to, amount);
    }

    function setBulkBlacklist(address[] memory users, bool state) external onlyOwner{
        uint256 size = users.length;
        for(uint256 i; i<size; ){
            isBlacklisted[users[i]] = state;
            unchecked {++i;}
        }
    }

    function setBlacklist(address user, bool state) external onlyOwner{
        isBlacklisted[user] = state;
    }

    function setBulkPair(address[] memory pairs, bool state) external onlyOwner{
        uint256 size = pairs.length;
        for(uint256 i; i<size; ){
            isPair[pairs[i]] = state;
            unchecked {++i;}
        }
    }

    function setPair(address pair, bool state) external onlyOwner{
        isPair[pair] = state;
    }

    function setBulkExempt(address[] memory users, bool state) external onlyOwner{
        uint256 size = users.length;
        for(uint256 i; i<size; ){
            isExempt[users[i]] = state;
            unchecked {++i;}
        }
    }

    function setExempt(address user, bool state) external onlyOwner{
        isExempt[user] = state;
    }

    function setMaxWallet(uint256 amount) external onlyOwner{
        maxWallet = amount * 10**18;
    }

}