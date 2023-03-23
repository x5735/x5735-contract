// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.10;

import {ContextUpgradeable} from "../../utils/ContextUpgradeable.sol";
import {
    ERC165Upgradeable,
    IERC165Upgradeable
} from "../../utils/introspection/ERC165Upgradeable.sol";

import {IERC721Upgradeable} from "./IERC721Upgradeable.sol";
import {
    IERC721MetadataUpgradeable
} from "./extensions/IERC721MetadataUpgradeable.sol";

import {BitMapsUpgradeable} from "../../utils/structs/BitMapsUpgradeable.sol";

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721Upgradeable is
    ContextUpgradeable,
    ERC165Upgradeable,
    IERC721Upgradeable,
    IERC721MetadataUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;

    function _baseURI() internal view virtual returns (string memory);

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => bytes32) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;

    function ownerOf(
        uint256 id
    ) public view virtual override returns (address owner) {
        assembly {
            mstore(0x00, id)
            mstore(0x20, _ownerOf.slot)
            owner := sload(keccak256(0x00, 0x40))

            if iszero(owner) {
                // Store the function selector of `ERC721__NotMinted()`.
                // Revert with (offset, size).
                mstore(0x00, 0xf2c8ced6)
                revert(0x1c, 0x04)
            }
        }
    }

    function balanceOf(
        address owner
    ) public view virtual returns (uint256 balance_) {
        assembly {
            if iszero(owner) {
                // Store the function selector of `ERC721__NonZeroAddress()`.
                // Revert with (offset, size).
                mstore(0, 0xf8a06d80)
                revert(0x1c, 0x04)
            }

            // balance_ = _balanceOf[owner]
            mstore(0x00, owner)
            mstore(0x20, _balanceOf.slot)
            balance_ := sload(keccak256(0x00, 0x40))
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => bytes32) internal _getApproved;

    mapping(address => BitMapsUpgradeable.BitMap) internal _isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(
        string calldata name_,
        string calldata symbol_
    ) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        if (bytes(name_).length > 32 || bytes(symbol_).length > 32)
            revert ERC721__StringTooLong();

        name = name_;
        symbol = symbol_;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address sender = _msgSender();
        assembly {
            /// @dev owner = _ownerOf[id]
            mstore(0x00, id)
            mstore(0x20, _ownerOf.slot)
            let owner := sload(keccak256(0x00, 0x40))

            /// @dev if (sender != owner)
            if iszero(eq(sender, owner)) {
                // check whether sender has approval for all id of owner
                mstore(0x00, owner)
                mstore(0x20, _isApprovedForAll.slot)
                // store _isApprovedForAll[owner] key at 0x20
                mstore(0x20, keccak256(0x00, 0x40))
                // override last 248 bit of sender as index to 0x00 for hashing
                mstore(0x00, shr(0x08, sender))

                // revert if the approved bit is not set
                if iszero(
                    and(
                        sload(keccak256(0x00, 0x40)),
                        shl(and(sender, 0xff), 0x01)
                    )
                ) {
                    // Store the function selector of `ERC721__Unauthorized()`.
                    // Revert with (offset, size).
                    mstore(0x00, 0x1fad8706)
                    revert(0x1c, 0x04)
                }
            }

            //  _getApproved[id] = spender
            mstore(0x00, id)
            mstore(0x20, _getApproved.slot)
            sstore(keccak256(0x00, 0x40), spender)

            // emit Approval(owner, spender, id)
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("Approval(address,address,uint256)")
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                owner,
                spender,
                id
            )
        }
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual {
        address sender = _msgSender();
        assembly {
            //  _isApprovedForAll[sender].setTo(operator, approved)
            mstore(0, sender)
            mstore(32, _isApprovedForAll.slot)
            mstore(32, keccak256(0, 64))
            mstore(0, shr(8, operator))

            let mapKey := keccak256(0, 64)
            let value := sload(mapKey)

            // The following sets the bit at `shift` without branching.
            let shift := and(operator, 0xff)
            // Isolate the bit at `shift`.
            let x := and(shr(shift, value), 1)
            // Xor it with `shouldSet`. Results in 1 if both are different, else 0.
            x := xor(x, approved)
            // Shifts the bit back. Then, xor with value.
            // Only the bit at `shift` will be flipped if they differ.
            // Every other bit will stay the same, as they are xor'ed with zeroes.
            value := xor(value, shl(shift, x))

            sstore(mapKey, value)

            //  emit ApprovalForAll(sender, operator, approved)
            mstore(0x00, approved)

            log3(
                0x00,
                0x20,
                /// @dev value is equal to keccak256("ApprovalForAll(address,address,bool)")
                0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31,
                sender,
                operator
            )
        }
    }

    function getApproved(
        uint256 tokenId
    ) external view override returns (address approval) {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, _getApproved.slot)
            approval := sload(keccak256(0x00, 0x40))
        }
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool approved) {
        assembly {
            mstore(0x00, owner)
            mstore(0x20, _isApprovedForAll.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, shr(0x08, operator))
            approved := and(
                sload(keccak256(0x00, 0x40)),
                shl(and(operator, 0xff), 1)
            )
        }
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool isApprovedOrOwner_) {
        address owner = ownerOf(tokenId);
        assembly {
            // if spender is owner
            if eq(spender, owner) {
                isApprovedOrOwner_ := true
            }

            if iszero(isApprovedOrOwner_) {
                // if _getApproved[tokenId] == spender
                mstore(0x00, tokenId)
                mstore(0x20, _getApproved.slot)
                let approved := sload(keccak256(0x00, 0x40))
                if eq(approved, spender) {
                    isApprovedOrOwner_ := true
                }

                if iszero(isApprovedOrOwner_) {
                    // if _isApprovedForAll[owner][spender] == true
                    mstore(0x00, owner)
                    mstore(0x20, _isApprovedForAll.slot)
                    // store _isApprovedForAll[owner] key at 0x20
                    mstore(0x20, keccak256(0x00, 0x40))

                    // store last 248 bit of spender as index
                    mstore(0x00, shr(0x08, spender))

                    // check if the bit is turned in the bitmap
                    approved := and(
                        sload(keccak256(0x00, 0x40)),
                        shl(and(spender, 0xff), 1)
                    )

                    if approved {
                        isApprovedOrOwner_ := true
                    }
                }
            }
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /* firstTokenId */,
        uint256 batchSize
    ) internal virtual {
        assembly {
            if gt(batchSize, 1) {
                mstore(0x20, _balanceOf.slot)
                let key
                let balanceBefore
                if iszero(iszero(from)) {
                    mstore(0x00, from)
                    key := keccak256(0x00, 0x40)
                    balanceBefore := sload(key)
                    //  underflow check
                    if gt(balanceBefore, batchSize) {
                        revert(0, 0)
                    }
                    sstore(key, sub(balanceBefore, batchSize))
                }
                if iszero(iszero(to)) {
                    mstore(0x00, to)
                    key := keccak256(0x00, 0x40)
                    balanceBefore := sload(key)
                    //  overflow check
                    balanceBefore := add(balanceBefore, batchSize)
                    if lt(balanceBefore, batchSize) {
                        revert(0, 0)
                    }
                    sstore(key, balanceBefore)
                }
            }
        }
    }

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        _beforeTokenTransfer(from, to, id, 1);

        address sender = _msgSender();
        assembly {
            if iszero(to) {
                // Store the function selector of `ERC721__InvalidRecipient()`.
                // Revert with (offset, size).
                mstore(0x00, 0x28ede692)
                revert(0x1c, 0x04)
            }

            mstore(0x00, id)
            mstore(32, _ownerOf.slot)
            let ownerOfKey := keccak256(0, 64)

            if iszero(eq(from, sload(ownerOfKey))) {
                // Store the function selector of `ERC721__WrongFrom()`.
                // Revert with (offset, size).
                mstore(0x00, 0x0ef14eef)
                revert(0x1c, 0x04)
            }

            mstore(0x20, _getApproved.slot)
            let approvedKey := keccak256(0x00, 0x40)

            if iszero(eq(sender, from)) {
                if iszero(eq(sender, sload(approvedKey))) {
                    mstore(0x00, from)
                    mstore(0x20, _isApprovedForAll.slot)

                    mstore(0x20, keccak256(0x00, 0x40))
                    mstore(0x00, shr(0x08, sender))

                    if iszero(
                        and(sload(keccak256(0, 64)), shl(and(sender, 0xff), 1))
                    ) {
                        // Store the function selector of `ERC721__Unauthorized()`.
                        // Revert with (offset, size).
                        mstore(0x00, 0x1fad8706)
                        revert(0x1c, 0x04)
                    }
                }
            }

            // Underflow of the sender's balance is impossible because we check for
            // ownership above and the recipient's balance can't realistically

            //  ++_balanceOf[to];
            mstore(0x00, to)
            mstore(0x20, _balanceOf.slot)
            let key := keccak256(0x00, 0x40)
            let balanceBefore := add(1, sload(key))
            sstore(key, balanceBefore)

            //  --_balanceOf[from];
            mstore(0x00, from)
            key := keccak256(0x00, 0x40)
            balanceBefore := sub(sload(key), 1)
            sstore(key, balanceBefore)

            //  _ownerOf[id] = to
            sstore(ownerOfKey, to)
            //  delete _getApproved[id];
            sstore(approvedKey, 0)

            // emit Transfer(from, to, id);
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("Transfer(address,address,uint256)")
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                to,
                id
            )
        }

        _afterTokenTransfer(from, to, id, 1);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            !(to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    from,
                    id,
                    ""
                ) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector)
        ) revert ERC721__UnsafeRecipient();
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        _beforeTokenTransfer(from, to, tokenId, 1);

        assembly {
            // if to == address(0) revert
            if iszero(to) {
                // Store the function selector of `ERC721__InvalidRecipient()`.
                // Revert with (offset, size).
                mstore(0x00, 0x28ede692)
                revert(0x1c, 0x04)
            }

            // cache tokenId at 0x00 for later use
            mstore(0x00, tokenId)
            mstore(0x20, _ownerOf.slot)
            let key := keccak256(0x00, 0x40)

            if iszero(eq(from, sload(key))) {
                // Store the function selector of `ERC721__WrongFrom()`.
                // Revert with (offset, size).
                mstore(0x00, 0x0ef14eef)
                revert(0x1c, 0x04)
            }

            //  _ownerOf[tokenId] = to
            sstore(key, to)

            //  emit Transfer(from, to, tokenId);
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("Transfer(address,address,uint256)")
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                to,
                tokenId
            )

            // delete _getApproved[tokenId];
            mstore(0x20, _getApproved.slot)
            sstore(keccak256(0x00, 0x40), 0)

            // ++_balanceOf[to]
            // cached _balanceOf slot for later use
            mstore(0x20, _balanceOf.slot)
            mstore(0x00, to)
            key := keccak256(0x00, 0x40)
            sstore(key, add(1, sload(key)))

            // --_balanceOf[from]
            mstore(0x00, from)
            key := keccak256(0x00, 0x40)
            sstore(key, sub(sload(key), 1))
        }

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);
        if (
            !(to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    from,
                    id,
                    data
                ) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector)
        ) revert ERC721__UnsafeRecipient();
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        _beforeTokenTransfer(address(0), to, id, 1);

        assembly {
            if iszero(to) {
                // Store the function selector of `ERC721__InvalidRecipient()`.
                // Revert with (offset, size).
                mstore(0x00, 0x28ede692)
                revert(0x1c, 0x04)
            }

            mstore(0x00, id)
            mstore(0x20, _ownerOf.slot)
            let key := keccak256(0x00, 0x40)
            /// @dev cachedVal = _ownerOf[id]
            let cachedVal := sload(key)

            /// @dev if (owner != 0) revert
            if iszero(iszero(cachedVal)) {
                mstore(0x00, 0xec125a85)
                revert(0x1c, 0x04)
            }

            /// @dev emit Transfer(address(0), to, id)
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("Transfer(address,address,uint256)")
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0,
                to,
                id
            )

            /// @dev _ownerOf[id] = to
            sstore(key, to)

            mstore(0x00, to)
            mstore(0x20, _balanceOf.slot)
            key := keccak256(0x00, 0x40)
            /// @dev cachedVal = _balanceOf[to] + 1
            cachedVal := add(sload(key), 1)
            sstore(key, cachedVal)
        }

        _afterTokenTransfer(address(0), to, id, 1);
    }

    function _burn(uint256 id) internal virtual {
        bytes32 key;
        address owner;
        assembly {
            mstore(0x00, id)
            mstore(0x20, _ownerOf.slot)
            key := keccak256(0x00, 0x40)
            owner := sload(key)
            if iszero(owner) {
                // Store the function selector of `ERC721__NotMinted()`.
                // Revert with (offset, size).
                mstore(0x00, 0xf2c8ced6)
                revert(0x1c, 0x04)
            }
        }

        _beforeTokenTransfer(owner, address(0), id, 1);

        assembly {
            // delete _ownerOf[id]
            sstore(key, 0)

            //  delete _getApproved[id];
            mstore(0x00, id)
            mstore(0x20, _getApproved.slot)
            sstore(keccak256(0x00, 0x40), 0)

            //  emit Transfer(owner, address(0), id);
            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("Transfer(address,address,uint256)")
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                owner,
                0,
                id
            )

            // Ownership check above ensures no underflow.
            //  --_balanceOf[owner]
            mstore(0x00, owner)
            mstore(0x20, _balanceOf.slot)
            key := keccak256(0x00, 0x40)
            sstore(key, sub(sload(key), 1))
        }

        _afterTokenTransfer(owner, address(0), id, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if (
            !(to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    address(0),
                    id,
                    ""
                ) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector)
        ) revert ERC721__UnsafeRecipient();
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);
        if (
            !(to.code.length == 0 ||
                ERC721TokenReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    address(0),
                    id,
                    data
                ) ==
                ERC721TokenReceiverUpgradeable.onERC721Received.selector)
        ) revert ERC721__UnsafeRecipient();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiverUpgradeable {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiverUpgradeable.onERC721Received.selector;
    }
}