// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAnito.sol";

contract Summoner is Ownable, Pausable, ReentrancyGuard {
    IAnito public anitoNFT;
    address signer;
    mapping(uint256 => bool) usedNonces;

    event SummoningExecuted(
        uint256 tokenId,
        uint256 _anito1,
        uint256 _anito2,
        uint256 rarityStoneType,
        uint256 classStoneType,
        uint256 statStoneType1,
        uint256 statStoneType2
    );

    constructor(address _anitoNFT, address _signer) {
        anitoNFT = IAnito(_anitoNFT);
        signer = _signer;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function summon(
        uint256 _anito1,
        uint256 _anito2,
        uint256 rarityStoneType,
        uint256 classStoneType,
        uint256 statStoneType1,
        uint256 statStoneType2,
        uint256 nonce,
        bytes memory _sig
    ) public nonReentrant whenNotPaused {
        require(anitoNFT.ownerOf(_anito1) == msg.sender, "Not owned anito");
        require(anitoNFT.ownerOf(_anito2) == msg.sender, "Not owned anito");
        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _anito1,
                    _anito2,
                    rarityStoneType,
                    classStoneType,
                    statStoneType1,
                    statStoneType2,
                    nonce
                )
            )
        );
        require(recoverSigner(message, _sig) == signer, "Invalid signer");
        require(!usedNonces[nonce], "nonce already used");

        anitoNFT.executeSummoning(
            msg.sender,
            _anito1,
            _anito2,
            rarityStoneType,
            classStoneType,
            statStoneType1,
            statStoneType2
        );

        emit SummoningExecuted(
            anitoNFT.totalSupply(),
            _anito1,
            _anito2,
            rarityStoneType,
            classStoneType,
            statStoneType1,
            statStoneType2
        );
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (uint8, bytes32, bytes32) {
        require(sig.length == 65, "Incorrect signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            //first 32 bytes, after the length prefix
            r := mload(add(sig, 0x20))
            //next 32 bytes
            s := mload(add(sig, 0x40))
            //final byte, first of next 32 bytes
            v := byte(0, mload(add(sig, 0x60)))
        }

        return (v, r, s);
    }

    function recoverSigner(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }
}