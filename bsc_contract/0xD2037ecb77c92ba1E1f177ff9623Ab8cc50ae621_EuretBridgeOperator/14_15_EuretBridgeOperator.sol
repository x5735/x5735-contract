// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./EURETToken.sol";

contract EuretBridgeOperator is AccessControl, ReentrancyGuard {
    EuroLinkedStableCoin token;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external nonReentrant onlyRole(MINTER_ROLE) {
        token.mint(_to, _amount);
    }

    function burnFrom(uint256 _amount) external nonReentrant {
        token.burnFrom(msg.sender, _amount);
    }

    function setTokenAddress(
        address _addr
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        token = EuroLinkedStableCoin(_addr);
    }
}