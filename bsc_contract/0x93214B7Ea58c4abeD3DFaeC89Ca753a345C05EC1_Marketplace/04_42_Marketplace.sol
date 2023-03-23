// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    BitMapsUpgradeable
} from "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";

import {
    SignableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
import {
    ProxyCheckerUpgradeable
} from "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";

import {
    Roles,
    IAuthority,
    ManagerUpgradeable
} from "oz-custom/contracts/presets-upgradeable/base/ManagerUpgradeable.sol";

import {
    BKFundForwarderUpgradeable
} from "./internal-upgradeable/BKFundForwarderUpgradeable.sol";

import {IBKTreasury} from "./interfaces/IBKTreasury.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {
    IWithdrawableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";

import {
    IFundForwarderUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IFundForwarderUpgradeable.sol";

import {
    IERC721PermitUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/IERC721PermitUpgradeable.sol";

import {
    IERC20Upgradeable,
    IERC20PermitUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";

import {
    FixedPointMathLib
} from "oz-custom/contracts/libraries/FixedPointMathLib.sol";

import {Bytes32Address} from "oz-custom/contracts/libraries/Bytes32Address.sol";

contract Marketplace is
    IMarketplace,
    ManagerUpgradeable,
    SignableUpgradeable,
    BKFundForwarderUpgradeable
{
    using Bytes32Address for *;
    using FixedPointMathLib for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    uint256 public constant PERCENTAGE_FRACTION = 10_000;

    /// @dev value is equal to keccak256("Permit(address buyer,address nft,address payment,uint256 price,uint256 tokenId,uint256 nonce,uint256 deadline)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xc396b6309f782cacc3389f4dd579db291ad1b771b8b4966f3695dab14150633e;

    uint256 public protocolFee;
    BitMapsUpgradeable.BitMap private __whitelistedContracts;

    function initialize(
        uint256 feeFraction_,
        IAuthority authority_,
        address[] calldata supportedContracts_
    ) external initializer {
        __Signable_init_unchained(type(Marketplace).name, "1");
        __Manager_init_unchained(authority_, Roles.TREASURER_ROLE);
        __Marketplace_init_unchained(feeFraction_, supportedContracts_);
        __FundForwarder_init_unchained(
            IFundForwarderUpgradeable(address(authority_)).vault()
        );
    }

    function __Marketplace_init_unchained(
        uint256 feeFraction_,
        address[] calldata supportedContracts_
    ) internal onlyInitializing {
        __setProtocolFee(feeFraction_);
        __whiteListContracts(supportedContracts_);
    }

    function changeVault(
        address vault_
    ) external override onlyRole(Roles.TREASURER_ROLE) {
        _changeVault(vault_);
    }

    function whiteListContracts(
        address[] calldata addrs_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        __whiteListContracts(addrs_);
    }

    function setProtocolFee(
        uint256 feeFraction_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        __setProtocolFee(feeFraction_);
    }

    function redeem(
        uint256 deadline_,
        Buyer calldata buyer_,
        Seller calldata sellItem_,
        bytes calldata signature_
    ) external payable whenNotPaused {
        address buyer = _msgSender();
        _onlyEOA(buyer);
        _checkBlacklist(buyer);

        __checkSignature(buyer, deadline_, sellItem_, signature_);

        address seller = sellItem_.nft.ownerOf(sellItem_.tokenId);
        __transferItem(buyer, seller, sellItem_);
        __processPayment(buyer, seller, buyer_, sellItem_);

        emit Redeemed(buyer, seller, sellItem_);
    }

    function nonces(address account_) external view returns (uint256) {
        return _nonces[account_.fillLast12Bytes()];
    }

    function isWhitelisted(address addr_) external view returns (bool) {
        return __whitelistedContracts.get(addr_.fillLast96Bits());
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

    function __setProtocolFee(uint256 feeFraction_) private {
        protocolFee = feeFraction_;
        emit ProtocolFeeUpdated(_msgSender(), feeFraction_);
    }

    function __transferItem(
        address buyerAddr_,
        address sellerAddr_,
        Seller calldata seller_
    ) private {
        uint256 tokenId = seller_.tokenId;
        IERC721PermitUpgradeable nft = seller_.nft;

        if (!__whitelistedContracts.get(address(nft).fillLast96Bits()))
            revert Marketplace__UnsupportedNFT();

        if (nft.getApproved(tokenId) != address(this))
            nft.permit(
                address(this),
                tokenId,
                seller_.deadline,
                seller_.signature
            );

        nft.safeTransferFrom(sellerAddr_, buyerAddr_, tokenId);
    }

    function __processPayment(
        address buyerAddr_,
        address sellerAddr_,
        Buyer calldata buyer_,
        Seller calldata seller_
    ) private {
        uint256 _protocolFee = protocolFee;
        uint256 percentageFraction = PERCENTAGE_FRACTION;
        uint256 receiveFraction = percentageFraction - _protocolFee;
        address _vault = vault();

        bytes memory emptyBytes = "";

        if (!IBKTreasury(_vault).supportedPayment(seller_.payment))
            revert Marketplace__UnsupportedPayment();

        if (address(seller_.payment) != address(0)) {
            if (
                IERC20Upgradeable(seller_.payment).allowance(
                    buyerAddr_,
                    address(this)
                ) < seller_.unitPrice
            )
                IERC20PermitUpgradeable(seller_.payment).permit(
                    buyerAddr_,
                    address(this),
                    seller_.unitPrice,
                    buyer_.deadline,
                    buyer_.v,
                    buyer_.r,
                    buyer_.s
                );

            _safeERC20TransferFrom(
                IERC20Upgradeable(seller_.payment),
                buyerAddr_,
                sellerAddr_,
                seller_.unitPrice.mulDivDown(
                    receiveFraction,
                    percentageFraction
                )
            );
            if (_protocolFee != 0) {
                uint256 received;
                _safeERC20TransferFrom(
                    IERC20Upgradeable(seller_.payment),
                    buyerAddr_,
                    _vault,
                    received = seller_.unitPrice.mulDivDown(
                        _protocolFee,
                        percentageFraction
                    )
                );
                if (
                    IWithdrawableUpgradeable(_vault).notifyERC20Transfer(
                        address(seller_.payment),
                        received,
                        safeTransferHeader()
                    ) != IWithdrawableUpgradeable.notifyERC20Transfer.selector
                ) revert Marketplace__ExecutionFailed();
            }

            if (msg.value == 0) return;
            _safeNativeTransfer(buyerAddr_, msg.value, emptyBytes);
        } else {
            uint256 refund = msg.value - seller_.unitPrice;

            _safeNativeTransfer(
                sellerAddr_,
                seller_.unitPrice.mulDivDown(
                    receiveFraction,
                    percentageFraction
                ),
                emptyBytes
            );
            if (_protocolFee != 0)
                _safeNativeTransfer(
                    _vault,
                    seller_.unitPrice.mulDivDown(
                        _protocolFee,
                        percentageFraction
                    ),
                    emptyBytes
                );

            if (refund == 0) return;
            _safeNativeTransfer(buyerAddr_, refund, emptyBytes);
        }
    }

    function __whiteListContracts(
        address[] calldata supportedContracts_
    ) private {
        uint256[] memory uintContracts;
        address[] memory supportedContracts = supportedContracts_;
        assembly {
            uintContracts := supportedContracts
        }

        uint256 length = supportedContracts_.length;
        for (uint256 i; i < length; ) {
            __whitelistedContracts.set(uintContracts[i]);
            unchecked {
                ++i;
            }
        }

        emit TokensWhitelisted(_msgSender(), supportedContracts_);
    }

    function __checkSignature(
        address buyer,
        uint256 deadline_,
        Seller calldata sellItem,
        bytes calldata signature_
    ) private {
        if (block.timestamp > deadline_) revert Marketplace__Expired();
        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            __PERMIT_TYPE_HASH,
                            buyer,
                            sellItem.nft,
                            sellItem.payment,
                            sellItem.unitPrice,
                            sellItem.tokenId,
                            _useNonce(buyer.fillLast12Bytes()),
                            deadline_
                        )
                    ),
                    signature_
                )
            )
        ) revert Marketplace__InvalidSignature();
    }

    uint256[48] private __gap;
}