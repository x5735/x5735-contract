// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../interfaces/ICoriteMNFT.sol";

contract NFTBurner is AccessControl, Pausable {
    bytes32 public constant ADMIN = keccak256("ADMIN");

    IERC20 public immutable CO_TOKEN;
    ICoriteMNFT public immutable CO_VARIOUS;
    address private serverPubKey;

    constructor(
        IERC20 _coToken,
        ICoriteMNFT _CO_VARIOUS,
        address _default_admin_role
    ) {
        CO_TOKEN = _coToken;
        CO_VARIOUS = _CO_VARIOUS;
        _setupRole(DEFAULT_ADMIN_ROLE, _default_admin_role);
        _setupRole(ADMIN, _default_admin_role);
    }

    function burnAndClaim(
        uint[] calldata _tokenIds,
        uint _COReward,
        bytes calldata _prefix,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public whenNotPaused {
        bytes memory message = abi.encode(
            msg.sender,
            address(CO_VARIOUS),
            _tokenIds,
            _COReward
        );

        require(
            ecrecover(
                keccak256(abi.encodePacked(_prefix, message)),
                _v,
                _r,
                _s
            ) == serverPubKey,
            "Invalid signature"
        );

        for (uint i = 0; i < _tokenIds.length; i++) {
            require(
                CO_VARIOUS.ownerOf(_tokenIds[i]) == msg.sender,
                "Invalid NFT Owner"
            );

            CO_VARIOUS.burn(_tokenIds[i]);
        }

        CO_TOKEN.transfer(msg.sender, _COReward);
    }

    function changeServerKey(address _sK) public onlyRole(ADMIN) {
        serverPubKey = _sK;
    }

    function drain(address _to, uint _amount) public onlyRole(ADMIN) {
        CO_TOKEN.transfer(_to, _amount);
    }

    function pauseHandler() public onlyRole(ADMIN) {
        _pause();
    }

    function unpauseHandler() public onlyRole(ADMIN) {
        _unpause();
    }
}