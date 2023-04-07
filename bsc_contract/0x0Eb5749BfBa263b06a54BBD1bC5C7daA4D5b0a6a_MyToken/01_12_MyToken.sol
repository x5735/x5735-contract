// SPDX-License-Identifier: MIT

//pragma solidity >=0.6.0 <0.9.0;
pragma solidity ^0.8.1;

//./../node_modules/
import "ERC20.sol";
import "AccessControl.sol";
import "Ownable.sol";

contract MyToken is ERC20, AccessControl, Ownable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, getTokensAsMinimum(initialSupply));
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(MINTER_ROLE) {
        _burn(from, amount);
    }

    function grantMinterRole(address account) public onlyOwner {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) public onlyOwner {
        revokeRole(MINTER_ROLE, account);
    }

    function getTokensAsMinimum(uint256 amount) public view returns (uint256) {
        return amount * 10 ** decimals();
    }
}