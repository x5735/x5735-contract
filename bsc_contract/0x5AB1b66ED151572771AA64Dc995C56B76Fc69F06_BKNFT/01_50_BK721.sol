// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    ERC721Upgradeable,
    IERC165Upgradeable,
    ERC721PermitUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/ERC721PermitUpgradeable.sol";
import {
    ERC721EnumerableUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {
    Roles,
    IAuthority,
    ManagerUpgradeable
} from "oz-custom/contracts/presets-upgradeable/base/ManagerUpgradeable.sol";
import {
    ProtocolFeeUpgradeable
} from "oz-custom/contracts/internal-upgradeable/ProtocolFeeUpgradeable.sol";
import {
    BKFundForwarderUpgradeable
} from "./internal-upgradeable/BKFundForwarderUpgradeable.sol";
import {
    IWithdrawableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";

import {
    IFundForwarderUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IFundForwarderUpgradeable.sol";

import {IBK721} from "./interfaces/IBK721.sol";
import {IBKTreasury} from "./interfaces/IBKTreasury.sol";

import {SSTORE2} from "oz-custom/contracts/libraries/SSTORE2.sol";
import {StringLib} from "oz-custom/contracts/libraries/StringLib.sol";
import {Bytes32Address} from "oz-custom/contracts/libraries/Bytes32Address.sol";

abstract contract BK721 is
    IBK721,
    ManagerUpgradeable,
    ProtocolFeeUpgradeable,
    ERC721PermitUpgradeable,
    BKFundForwarderUpgradeable,
    ERC721EnumerableUpgradeable
{
    using SSTORE2 for *;
    using StringLib for *;
    using Bytes32Address for *;

    bytes32 private __baseTokenURIPtr;

    mapping(uint256 => uint256) public typeIdTrackers;

    mapping(address => mapping(uint248 => uint256)) private __nonceBitMaps;

    function redeemBulk(
        uint256 nonce_,
        uint256 amount_,
        uint256 typeId_,
        address claimer_,
        uint256 deadline_,
        bytes calldata signature_
    ) external {
        if (deadline_ < block.timestamp) revert BK721__Expired();
        _requireNotPaused();

        address sender = _msgSender();

        address[] memory addrs = new address[](2);
        addrs[0] = claimer_;
        addrs[1] = sender;

        _checkBlacklistMulti(addrs);

        _invalidateNonce(sender, claimer_, nonce_);

        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            ///@dev value is equal to keccak256("Redeem(address claimer,uint256 typeId,uint256 amount,uint256 nonce,uint256 deadline)")
                            0x77ef6871868b6364332f0081c63b10b340f7531a5d1010a6bd3356568ffcf11d,
                            claimer_,
                            typeId_,
                            amount_,
                            // @dev resitance to reentrancy
                            nonce_,
                            deadline_
                        )
                    ),
                    signature_
                )
            )
        ) revert BK721__InvalidSignature();

        uint256 cursor = nextIdFromType(typeId_);
        for (uint256 i; i < amount_; ) {
            unchecked {
                _mint(claimer_, cursor);
                ++cursor;
                ++i;
            }
        }

        typeIdTrackers[typeId_] = cursor;

        emit Redeemded(sender, claimer_, typeId_, amount_);
    }

    function changeVault(
        address vault_
    ) external override onlyRole(Roles.TREASURER_ROLE) {
        _changeVault(vault_);
    }

    function setBaseURI(
        string calldata baseURI_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        _setBaseURI(baseURI_);
    }

    function merge(
        uint256[] calldata fromIds_,
        uint256 toId_,
        uint256 deadline_,
        bytes calldata signature_
    ) external {
        if (block.timestamp > deadline_) revert BK721__Expired();

        address user = _msgSender();
        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            ///@dev value is equal to keccak256("Swap(address user,uint256 toId,uint256 deadline,uint256 nonce,uint256[] fromIds)")
                            0x085ba72701c4339ed5b893f5421cabf9405901f059ff0c12083eb0b1df6bc19a,
                            user,
                            toId_,
                            deadline_,
                            _useNonce(user.fillLast12Bytes()), // @dev resitance to reentrancy
                            keccak256(abi.encodePacked(fromIds_))
                        )
                    ),
                    signature_
                )
            )
        ) revert BK721__InvalidSignature();

        uint256 fromId;
        uint256 length = fromIds_.length;
        for (uint256 i; i < length; ) {
            fromId = fromIds_[i];
            if (ownerOf(fromId) != user) revert BK721__Unauthorized();
            if (fromId != toId_) _burn(fromId);

            unchecked {
                ++i;
            }
        }

        address ownerOfToId = ownerOf(toId_);
        if (!(ownerOfToId == address(0) || ownerOfToId == user))
            revert BK721__Unauthorized();

        if (ownerOfToId == address(0)) __mintTransfer(user, toId_);

        emit Merged(user, fromIds_, toId_);
    }

    function setRoyalty(
        address feeToken_,
        uint96 feeAmt_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        if (!IBKTreasury(vault()).supportedPayment(feeToken_))
            revert BK721__TokenNotSupported();

        _setRoyalty(feeToken_, feeAmt_);

        emit ProtocolFeeUpdated(_msgSender(), feeToken_, feeAmt_);
    }

    function safeMint(
        address to_,
        uint256 typeId_
    ) external onlyRole(Roles.PROXY_ROLE) returns (uint256 tokenId) {
        unchecked {
            _safeMint(
                to_,
                tokenId = (typeId_ << 32) | typeIdTrackers[typeId_]++
            );
        }
    }

    function mint(
        address to_,
        uint256 typeId_
    ) external onlyRole(Roles.MINTER_ROLE) returns (uint256 tokenId) {
        unchecked {
            _mint(to_, tokenId = (typeId_ << 32) | typeIdTrackers[typeId_]++);
        }
    }

    function transferBatch(
        address from_,
        address[] calldata tos_,
        uint256[] calldata tokenIds_
    ) external {
        uint256 length = tos_.length;
        if (length != tokenIds_.length) revert BK721__LengthMismatch();

        uint256 i;
        while (i < length && gasleft() > 250_000) {
            transferFrom(from_, tos_[i], tokenIds_[i]);
            unchecked {
                ++i;
            }
        }

        unchecked {
            emit BatchTransfered(
                _msgSender(),
                from_,
                i < length - 1 ? tokenIds_[i] : 0
            );
        }
    }

    function mintBatch(
        uint256 typeId_,
        address[] calldata tos_
    ) external onlyRole(Roles.MINTER_ROLE) {
        uint256 length = tos_.length;
        uint256 cursor = nextIdFromType(typeId_);
        for (uint256 i; i < length; ) {
            unchecked {
                _mint(tos_[i], cursor);
                ++cursor;
                ++i;
            }
        }

        typeIdTrackers[typeId_] = cursor;
        emit BatchMinted(_msgSender(), length, tos_);
    }

    function safeMintBatch(
        address to_,
        uint256 typeId_,
        uint256 length_
    ) external onlyRole(Roles.PROXY_ROLE) returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](length_);
        uint256 cursor = nextIdFromType(typeId_);
        for (uint256 i; i < length_; ) {
            unchecked {
                _safeMint(to_, tokenIds[i] = cursor);
                ++cursor;
                ++i;
            }
        }

        address sender = _msgSender();
        assembly {
            mstore(0x00, typeId_)
            mstore(0x20, typeIdTrackers.slot)
            sstore(keccak256(0x00, 0x40), cursor)

            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("BatchTransfered(address,address,uint256)")
                0xef50f834ec47321b2a791fa7e4f6ccb0ea5fb5852c73a68f7ce1ab9b759d609d,
                sender,
                to_,
                length_
            )
        }
    }

    function nonces(address account_) external view returns (uint256) {
        return _nonces[account_.fillLast12Bytes()];
    }

    function nonceBitMaps(
        address account_,
        uint256 nonce_
    ) external view returns (uint256 bitmap, bool isDirtied) {
        assembly {
            mstore(0x00, account_)
            mstore(0x20, __nonceBitMaps.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(
                0x00,
                and(
                    shr(8, nonce_),
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
            )

            bitmap := sload(keccak256(0x00, 0x40))
            isDirtied := iszero(iszero(and(bitmap, shl(and(nonce_, 0xff), 1))))
        }
    }

    function invalidateNonce(
        address account_,
        uint248 wordPos_,
        uint256 mask_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        _requirePaused();

        assembly {
            mstore(0x00, account_)
            mstore(0x20, __nonceBitMaps.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, wordPos_)
            let key := keccak256(0x00, 0x40)
            let bitmap := sload(key)
            sstore(key, or(bitmap, mask_))

            log4(
                0x00,
                0x20,
                /// @dev value is equal to keccak256("NonceUsed(address,address,uint256,uint248)")
                0x0df261ec91401191ee6858fdd0e1c4334f5faa334b5db219ea5847b0122164a8,
                caller(),
                account_,
                mask_
            )
        }
    }

    function baseURI() external view returns (string memory) {
        return string(__baseTokenURIPtr.read());
    }

    function metadataOf(
        uint256 tokenId_
    ) external view returns (uint256 typeId, uint256 index) {
        ownerOf(tokenId_);

        typeId = tokenId_ >> 32;
        index = tokenId_ & 0xffffffff;
    }

    function nextIdFromType(
        uint256 typeId_
    ) public view returns (uint256 nextId) {
        assembly {
            mstore(0x00, typeId_)
            mstore(0x20, typeIdTrackers.slot)

            nextId := or(shl(32, typeId_), sload(keccak256(0x00, 0x40)))
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        ownerOf(tokenId);
        return
            string(
                abi.encodePacked(
                    __baseTokenURIPtr.read(),
                    address(this).toHexString(),
                    "/",
                    tokenId.toString()
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId_
    )
        public
        view
        virtual
        override(ERC721PermitUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return
            type(IERC165Upgradeable).interfaceId == interfaceId_ ||
            super.supportsInterface(interfaceId_);
    }

    function version() public pure returns (bytes32) {
        /// @dev value is equal to keccak256("BKNFT_v1")
        return
            0x379792d4af837d435deaf8f2b7ca3c489899f24f02d5309487fe8be0aa778cca;
    }

    function _setBaseURI(string calldata baseURI_) internal {
        __baseTokenURIPtr = bytes(baseURI_).write();
    }

    function _invalidateNonce(
        address sender_,
        address account_,
        uint256 nonce_
    ) internal {
        assembly {
            mstore(0x00, account_)
            mstore(0x20, __nonceBitMaps.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            let wordPos := and(
                shr(8, nonce_),
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            mstore(0x00, wordPos)
            let key := keccak256(0x00, 0x40)
            let bitmap := sload(key)
            let bitPosMask := shl(and(nonce_, 0xff), 1)
            if iszero(iszero(and(bitmap, bitPosMask))) {
                mstore(0x00, 0x716c4752)
                revert(0x1c, 0x04)
            }
            sstore(key, or(bitmap, bitPosMask))

            log4(
                0x00,
                0x20,
                /// @dev value is equal to keccak256("NonceUsed(address,address,uint256,uint248)")
                0x0df261ec91401191ee6858fdd0e1c4334f5faa334b5db219ea5847b0122164a8,
                sender_,
                account_,
                bitPosMask
            )
        }
    }

    function __BK_init(
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_,
        uint96 feeAmt_,
        address feeToken_,
        IAuthority authority_
    ) internal onlyInitializing {
        __BK_init_unchained(baseURI_);
        __ERC721Permit_init(name_, symbol_);
        __Manager_init_unchained(authority_, 0);
        __ProtocolFee_init_unchained(feeToken_, feeAmt_);
        __FundForwarder_init_unchained(
            IFundForwarderUpgradeable(address(authority_)).vault()
        );
    }

    function __BK_init_unchained(
        string calldata baseURI_
    ) internal onlyInitializing {
        _setBaseURI(baseURI_);
    }

    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 batchSize_
    )
        internal
        virtual
        override(ERC721EnumerableUpgradeable, ERC721Upgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from_, to_, tokenId_, batchSize_);

        address sender = _msgSender();

        address[] memory addrs = new address[](3);
        addrs[0] = to_;
        addrs[1] = sender;
        addrs[2] = from_;

        _checkBlacklistMulti(addrs);

        if (
            (to_ == address(0) ||
                from_ == address(0) ||
                _hasRole(Roles.OPERATOR_ROLE, sender))
        ) return;

        FeeInfo memory _feeInfo = feeInfo;

        address token = _feeInfo.token;
        uint256 royalty = _feeInfo.royalty;

        if (royalty == 0) return;

        address _vault = vault();

        bytes memory _safeTransferHeader = safeTransferHeader();
        _safeTransferFrom(token, sender, _vault, royalty, _safeTransferHeader);
        if (token == address(0)) return;

        if (
            IWithdrawableUpgradeable(_vault).notifyERC20Transfer(
                token,
                royalty,
                _safeTransferHeader
            ) == IWithdrawableUpgradeable.notifyERC20Transfer.selector
        ) return;

        revert BK721__ExecutionFailed();
    }

    function __mintTransfer(address to_, uint256 tokenId_) private {
        _mint(address(this), tokenId_);
        _transfer(address(this), to_, tokenId_);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return string(__baseTokenURIPtr.read());
    }

    function _beforeRecover(
        bytes memory
    ) internal override whenPaused onlyRole(Roles.OPERATOR_ROLE) {}

    function _afterRecover(
        address,
        address,
        uint256,
        bytes memory
    ) internal override {}

    uint256[47] private __gap;
}

interface IBKNFT {
    function initialize(
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_,
        uint96 feeAmt_,
        address feeToken_,
        IAuthority authority_
    ) external;
}

contract BKNFT is IBKNFT, BK721 {
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

    uint256[50] private __gap;
}