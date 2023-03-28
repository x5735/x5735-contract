// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./mixins/signature-control.sol";
import "./mixins/role-control.sol";
import "./mixins/nonce-control.sol";



contract Treasury is RoleControl, SignatureControl, NonceControl {

    mapping(address => bool) isApprovedToken;


    event tokenApproved(
        address indexed token
    );

    event tokensDeposited(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    event adminTokenWithdraw(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    event TokenWithdraw(
        address indexed account,
        address indexed token,
        uint256 amount
    );


    constructor(address admin)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }


    modifier onlyApprovedToken(address token) {
        require(isApprovedToken[token], "Token is not approved for deposit");
        _;
    }


    function approveTokenUsage(address token) public onlyAdmin {
        isApprovedToken[token]=true;
        emit tokenApproved(address(token));
    }

    function adminWithdrawToken(IERC20 token, address to, uint256 amount) public onlyAdmin {
        token.transfer(to, amount);
        emit adminTokenWithdraw(to, address(token), amount);
    }

    function depositToken(uint256 amount, address token) public onlyApprovedToken(token) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit tokensDeposited(msg.sender, address(token), amount);
    }

    function withdrawToken(
        uint256 amount, 
        address token, 
        uint256 nonce, 
        uint256 timestamp, 
        bytes memory signature
    ) public onlyApprovedToken(token) onlyValidNonce(nonce) {
        bytes memory data = abi.encodePacked(
             _toAsciiString(msg.sender), 
            " is authorized to withdraw ", 
            Strings.toString(amount), 
            " of ", 
            _toAsciiString(token),
            " before ",
            Strings.toString(timestamp),
            ", ",
            Strings.toString(nonce)
        );
        bytes32 hash = _toEthSignedMessage(data);
        address signer = ECDSA.recover(hash, signature);
        require(isOperator(signer),"Mint not verified by operator");
        require(block.timestamp <= timestamp, "Outdated signed message");
        IERC20(token).transfer(msg.sender, amount);
        emit TokenWithdraw(msg.sender, token, amount);
    }

}