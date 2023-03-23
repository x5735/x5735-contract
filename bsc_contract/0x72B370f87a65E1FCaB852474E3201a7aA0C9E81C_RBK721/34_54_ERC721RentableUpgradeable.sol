// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC165Upgradeable, ERC721Upgradeable} from "../ERC721Upgradeable.sol";

import {IERC721RentableUpgradeable} from "./IERC721RentableUpgradeable.sol";

abstract contract ERC721RentableUpgradeable is
    ERC721Upgradeable,
    IERC721RentableUpgradeable
{
    mapping(uint256 => UserInfo) internal _users;

    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) public virtual {
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            revert ERC721Rentable__OnlyOwnerOrApproved();

        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, _users.slot)

            sstore(keccak256(0x00, 0x40), or(shl(160, expires), user))

            mstore(0x00, expires)
            log3(
                0x00,
                0x20,
                /// @dev value is equal to keccak256("UpdateUser(uint256,address,uint64)")
                0x4e06b4e7000e659094299b3533b47b6aa8ad048e95e872d23d1f4ee55af89cfe,
                tokenId,
                user
            )
        }
    }

    function userOf(
        uint256 tokenId
    ) public view virtual override returns (address user) {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, _users.slot)
            let rentInfo := sload(keccak256(0x00, 0x40))

            // leave dirty bytes uncleaned
            if gt(shr(160, rentInfo), timestamp()) {
                user := rentInfo
            }
        }
    }

    function userExpires(
        uint256 tokenId
    ) public view virtual override returns (uint256 expires) {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, _users.slot)
            expires := shr(160, sload(keccak256(0x00, 0x40)))
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165Upgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721RentableUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        assembly {
            if iszero(eq(from, to)) {
                mstore(0x00, firstTokenId)
                mstore(0x20, _users.slot)
                let key := keccak256(0x00, 0x40)
                let rentInfo := sload(key)

                if iszero(
                    iszero(
                        and(
                            rentInfo,
                            0xffffffffffffffffffffffffffffffffffffffff
                        )
                    )
                ) {
                    sstore(key, 0)

                    log3(
                        0x00,
                        0x08,
                        /// @dev value is equal to keccak256("UpdateUser(uint256,address,uint64)")
                        0x4e06b4e7000e659094299b3533b47b6aa8ad048e95e872d23d1f4ee55af89cfe,
                        0,
                        0
                    )
                }
            }
        }
    }

    uint256[49] private __gap;
}