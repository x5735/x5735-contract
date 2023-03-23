// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    ERC721RentableUpgradeable,
    IERC721RentableUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/ERC721RentableUpgradeable.sol";

import {IRBK721} from "./interfaces/IRBK721.sol";

import {IAuthority, IBKTreasury, BK721, Roles} from "./BK721.sol";

contract RBK721 is BK721, IRBK721, ERC721RentableUpgradeable {
    function initialize(
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_,
        uint96 feeAmt_,
        address feeToken_,
        IAuthority authority_
    ) external initializer {
        __BK_init(name_, symbol_, baseURI_, feeAmt_, feeToken_, authority_);
    }

    function setUser(
        address user_,
        uint256 tokenId,
        uint64 expires_,
        uint256 deadline_,
        bytes calldata signature_
    ) external whenNotPaused {
        address owner = ownerOf(tokenId);
        if (block.timestamp > deadline_) revert RBK721__Expired();

        _verify(
            owner,
            keccak256(
                abi.encode(
                    ///@dev value is equal to keccak256("Permit(address user,uint256 tokenId,uint256 expires,uint256 deadline,uint256 nonce)")
                    0x791d178915e3bc91599d5bc6c1eab516b25cb66fc0b46b415e2018109bbaa078,
                    user_,
                    tokenId,
                    expires_,
                    deadline_,
                    _useNonce(bytes32(tokenId))
                )
            ),
            signature_
        );

        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, _users.slot)
            let key := keccak256(0x00, 0x40)
            let data := sload(key)

            if iszero(and(data, 0xffffffffffffffffffffffffffffffffffffffff)) {
                mstore(0x00, 0xb5a13506)
                revert(0x1c, 0x04)
            }
            if gt(shr(data, 160), timestamp()) {
                mstore(0x00, 0xb5a13506)
                revert(0x1c, 0x04)
            }

            sstore(key, or(shl(160, expires_), user_))

            mstore(0x00, expires_)
            log3(
                0x00,
                0x20,
                /// @dev value is equal to keccak256("UpdateUser(uint256,address,uint64)")
                0x4e06b4e7000e659094299b3533b47b6aa8ad048e95e872d23d1f4ee55af89cfe,
                tokenId,
                user_
            )
        }
    }

    function setUser(
        uint256 tokenId_,
        address user_,
        uint64 expires_
    ) public override whenNotPaused {
        super.setUser(tokenId_, user_, expires_);
    }

    function supportsInterface(
        bytes4 interfaceId_
    ) public view override(BK721, ERC721RentableUpgradeable) returns (bool) {
        return
            interfaceId_ == type(IRBK721).interfaceId ||
            super.supportsInterface(interfaceId_);
    }

    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 batchSize_
    ) internal override(BK721, ERC721RentableUpgradeable) {
        super._beforeTokenTransfer(from_, to_, tokenId_, batchSize_);
    }

    uint256[50] private __gap;
}