// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import {ERC721Upgradeable, IERC165Upgradeable} from "../ERC721Upgradeable.sol";

import {Bytes32Address} from "../../../../libraries/Bytes32Address.sol";

import {
    IERC721EnumerableUpgradeable
} from "./IERC721EnumerableUpgradeable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721EnumerableUpgradeable is
    ERC721Upgradeable,
    IERC721EnumerableUpgradeable
{
    // Array with all token ids, used for enumeration
    uint256[] private __allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private __allTokensIndex;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private __ownedTokensIndex;

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private __ownedTokens;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
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
            interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view virtual override returns (uint256 tokenId) {
        assembly {
            mstore(0x00, owner)
            mstore(0x20, _balanceOf.slot)
            let _balance := sload(keccak256(0x00, 0x40))
            if gt(index, _balance) {
                mstore(0x00, 0xf67f2b58)
                revert(0x1c, 0x04)
            }
            if eq(index, _balance) {
                mstore(0x00, 0xf67f2b58)
                revert(0x1c, 0x04)
            }

            mstore(0x20, __ownedTokens.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, index)

            tokenId := sload(keccak256(0x00, 0x40))
        }
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply()
        public
        view
        virtual
        override
        returns (uint256 supply)
    {
        assembly {
            supply := sload(__allTokens.slot)
        }
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(
        uint256 index
    ) public view virtual override returns (uint256 tokenId) {
        assembly {
            let length := sload(__allTokens.slot)

            if gt(index, length) {
                mstore(0x00, 0x28c37220)
                revert(0x1c, 0x04)
            }
            if eq(index, length) {
                mstore(0x00, 0x28c37220)
                revert(0x1c, 0x04)
            }

            mstore(0x00, __allTokens.slot)
            tokenId := sload(add(keccak256(0x00, 0x20), shl(5, index)))
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        if (batchSize > 1)
            // Will only trigger during construction. Batch transferring (minting) is not available afterwards.
            revert ERC721Enumerable__ConsecutiveTransferNotSupported();

        if (from == address(0)) _addTokenToAllTokensEnumeration(firstTokenId);
        else if (from != to)
            _removeTokenFromOwnerEnumeration(from, firstTokenId);

        if (to == address(0))
            _removeTokenFromAllTokensEnumeration(firstTokenId);
        else if (to != from) _addTokenToOwnerEnumeration(to, firstTokenId);
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        assembly {
            // length = _balanceOf[to]
            mstore(0x00, to)
            mstore(0x20, _balanceOf.slot)
            let length := sload(keccak256(0x00, 0x40))

            // __ownedTokens[to][length] = tokenId;
            mstore(0x20, __ownedTokens.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, length)
            sstore(keccak256(0x00, 0x40), tokenId)

            // __ownedTokensIndex[tokenId] = length;
            mstore(0x00, tokenId)
            mstore(0x20, __ownedTokensIndex.slot)
            sstore(keccak256(0x00, 0x40), length)
        }
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        assembly {
            // __allTokensIndex[tokenId] = __allTokens.length;
            mstore(0x00, tokenId)
            mstore(0x20, __allTokensIndex.slot)
            let length := sload(__allTokens.slot)
            sstore(keccak256(0x00, 0x40), length)

            // ++__allTokens.length
            sstore(__allTokens.slot, add(1, length))
            // __allTokens[length] = tokenId
            mstore(0x00, __allTokens.slot)
            sstore(add(keccak256(0x00, 0x20), shl(5, length)), tokenId)
        }
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(
        address from,
        uint256 tokenId
    ) private {
        assembly {
            mstore(0x00, from)
            mstore(0x20, _balanceOf.slot)
            let lastTokenIndex := sload(keccak256(0x00, 0x40))
            //  underflow check
            if iszero(lastTokenIndex) {
                revert(0, 0)
            }

            lastTokenIndex := sub(lastTokenIndex, 1)

            mstore(0x00, tokenId)
            mstore(0x20, __ownedTokensIndex.slot)
            let ownedTokensIndexKey := keccak256(0x00, 0x40)
            let tokenIndex := sload(ownedTokensIndexKey)
            // cache __ownedtokens[from] key
            let ownedTokensFromLastKey
            // When the token to delete is the last token, the swap operation is unnecessary
            if iszero(eq(tokenIndex, lastTokenIndex)) {
                // lastTokenId = __ownedTokens[from][lastTokenIndex];
                mstore(0x00, from)
                mstore(0x20, __ownedTokens.slot)
                let ownedTokensFromKey := keccak256(0x00, 0x40)
                mstore(0x00, lastTokenIndex)
                mstore(0x20, ownedTokensFromKey)
                ownedTokensFromLastKey := keccak256(0x00, 0x40)
                let lastTokenId := sload(ownedTokensFromLastKey)

                // __ownedTokens[from][tokenIndex] = lastTokenId;
                // Move the last token to the slot of the to-delete token
                mstore(0x00, tokenIndex)
                mstore(0x20, ownedTokensFromKey)
                sstore(keccak256(0x00, 0x40), lastTokenId)

                // __ownedTokensIndex[lastTokenId] = tokenIndex;
                // Update the moved token's index
                mstore(0x00, lastTokenId)
                mstore(0x20, __ownedTokensIndex.slot)
                sstore(keccak256(0x00, 0x40), tokenIndex)
            }

            // This also deletes the contents at the last position of the array
            // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
            // then delete the last slot (swap and pop).

            // delete __ownedTokensIndex[tokenId];
            sstore(ownedTokensIndexKey, 0)

            // delete __ownedTokens[from][lastTokenIndex];
            sstore(ownedTokensFromLastKey, 0)
        }
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).
        assembly {
            // uint256 lastTokenIndex = __allTokens.length - 1;
            let lastTokenIndex := sload(__allTokens.slot)
            // underflow check
            if iszero(lastTokenIndex) {
                revert(0, 0)
            }
            lastTokenIndex := sub(lastTokenIndex, 1)

            // uint256 tokenIndex = __allTokensIndex[tokenId];
            mstore(0x00, tokenId)
            mstore(0x20, __allTokensIndex.slot)
            let allTokensIndexKey := keccak256(0x00, 0x40)
            let tokenIndex := sload(allTokensIndexKey)

            // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
            // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
            // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
            // uint256 lastTokenId = __allTokens[lastTokenIndex];
            mstore(0x00, __allTokens.slot)
            let lastTokenId := sload(
                add(shl(5, lastTokenIndex), keccak256(0x00, 0x20))
            )

            // __allTokens[tokenIndex] = lastTokenId;
            // Move the last token to the slot of the to-delete token
            sstore(add(shl(5, tokenIndex), keccak256(0x00, 0x20)), lastTokenId)

            // __allTokensIndex[lastTokenId] = tokenIndex;
            // Update the moved token's index
            mstore(0x00, lastTokenId)
            mstore(0x20, __allTokensIndex.slot)
            sstore(keccak256(0x00, 0x40), tokenIndex)

            // This also deletes the contents at the last position of the array
            //delete __allTokensIndex[tokenId];
            sstore(allTokensIndexKey, 0)

            //  __allTokens.pop();
            sstore(__allTokens.slot, lastTokenIndex)
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}