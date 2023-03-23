// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import {ERC721Upgradeable, IERC165Upgradeable} from "../ERC721Upgradeable.sol";
import {
    SignableUpgradeable
} from "../../../../internal-upgradeable/SignableUpgradeable.sol";

import {IERC721PermitUpgradeable} from "./IERC721PermitUpgradeable.sol";

/// @title ERC721 with permit
/// @notice Nonfungible tokens that support an approve via signature, i.e. permit
abstract contract ERC721PermitUpgradeable is
    ERC721Upgradeable,
    SignableUpgradeable,
    IERC721PermitUpgradeable
{
    function __ERC721Permit_init(
        string calldata name_,
        string calldata symbol_
    ) internal onlyInitializing {
        __EIP712_init_unchained(name_, "1");
        __ERC721_init_unchained(name_, symbol_);
    }

    /// @dev Gets the current nonce for a token ID and then increments it, returning the original value

    /// @inheritdoc IERC721PermitUpgradeable
    function DOMAIN_SEPARATOR()
        public
        view
        override(IERC721PermitUpgradeable, SignableUpgradeable)
        returns (bytes32)
    {
        return _domainSeparatorV4();
    }

    /// @dev Value is equal to to keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 private constant __PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    /// @inheritdoc IERC721PermitUpgradeable
    function permit(
        address spender_,
        uint256 tokenId_,
        uint256 deadline_,
        bytes calldata signature_
    ) external override {
        address owner = ownerOf(tokenId_);

        bytes32 digest;
        assembly {
            // if (block.timestamp > deadline_) revert ERC721Permit__Expired();
            if lt(deadline_, timestamp()) {
                mstore(0x00, 0x7b860b42)
                revert(0x1c, 0x04)
            }
            //  if (spender_ == owner) revert ERC721Permit__SelfApproving();
            if eq(spender_, owner) {
                mstore(0x00, 0x6916b4d5)
                revert(0x1c, 0x04)
            }

            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, __PERMIT_TYPEHASH)
            mstore(add(freeMemPtr, 0x20), spender_)

            mstore(add(freeMemPtr, 0x40), tokenId_)
            let nonceMemPtr := add(freeMemPtr, 0x60)
            mstore(nonceMemPtr, _nonces.slot)

            // increment nonce
            let nonceKey := keccak256(add(freeMemPtr, 0x40), 0x40)
            let nonce := sload(nonceKey)
            sstore(nonceKey, add(1, nonce))

            mstore(nonceMemPtr, nonce)
            mstore(add(freeMemPtr, 0x80), deadline_)
            digest := keccak256(freeMemPtr, 0xa0)
        }

        _verify(owner, digest, signature_);

        assembly {
            mstore(0x00, tokenId_)
            mstore(0x20, _getApproved.slot)
            sstore(keccak256(0x00, 0x40), spender_)
        }
    }

    function nonces(
        uint256 tokenId_
    ) external view override returns (uint256 nonce) {
        assembly {
            mstore(0x00, tokenId_)
            mstore(0x20, _nonces.slot)
            nonce := sload(keccak256(0x00, 0x40))
        }
    }

    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Overridden from ERC721 here in order to include the interface of this EIP
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721PermitUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}