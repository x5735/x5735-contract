// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    ERC165CheckerUpgradeable,
    BKFundForwarderUpgradeable
} from "./internal-upgradeable/BKFundForwarderUpgradeable.sol";

import {
    Roles,
    IAuthority,
    ManagerUpgradeable
} from "oz-custom/contracts/presets-upgradeable/base/ManagerUpgradeable.sol";

import {
    SignableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
import {
    TransferableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/TransferableUpgradeable.sol";
import {
    ProxyCheckerUpgradeable
} from "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
import {
    MultiDelegatecallUpgradeable
} from "oz-custom/contracts/internal-upgradeable/MultiDelegatecallUpgradeable.sol";

import {IGacha} from "./interfaces/IGacha.sol";
import {IBK721} from "./interfaces/IBK721.sol";
import {IBKTreasury} from "./interfaces/IBKTreasury.sol";
import {
    IWithdrawableUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";
import {
    IFundForwarderUpgradeable
} from "oz-custom/contracts/internal-upgradeable/interfaces/IFundForwarderUpgradeable.sol";
import {
    IERC721Upgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/IERC721PermitUpgradeable.sol";

import {Bytes32Address} from "oz-custom/contracts/libraries/Bytes32Address.sol";
import {
    BitMapsUpgradeable
} from "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";

contract Gacha is
    IGacha,
    ManagerUpgradeable,
    SignableUpgradeable,
    TransferableUpgradeable,
    BKFundForwarderUpgradeable
{
    using Bytes32Address for *;
    using ERC165CheckerUpgradeable for address;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev value is equal to keccak256("Claim(address token,uint256 ticketId,uint256 value,uint256 deadline,uint256 nonce)")
    bytes32 private constant __CLAIM_TYPE_HASH =
        0xff5122c8134d613571bf8ae24cff90116c8242a568b8dbe337419081fa1403bb;

    mapping(uint256 => Ticket) private __tickets;
    BitMapsUpgradeable.BitMap private __supportedPayments;
    mapping(uint256 => mapping(address => uint96)) private __unitPrices;

    function initialize(IAuthority authority_) external initializer {
        __Signable_init_unchained(type(Gacha).name, "1");
        __Manager_init_unchained(authority_, Roles.TREASURER_ROLE);
        __FundForwarder_init_unchained(
            IFundForwarderUpgradeable(address(authority_)).vault()
        );
    }

    function changeVault(
        address vault_
    ) external override onlyRole(Roles.TREASURER_ROLE) {
        _changeVault(vault_);
    }

    function updateTicketPrice(
        uint256 typeId_,
        address[] calldata supportedPayments_,
        uint96[] calldata unitPrices_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        address[] memory _supportedPayments = supportedPayments_;
        uint256[] memory uintPayments;
        assembly {
            uintPayments := _supportedPayments
        }
        uint256 length = supportedPayments_.length;
        for (uint256 i; i < length; ) {
            __supportedPayments.set(uintPayments[i]);
            __unitPrices[typeId_][supportedPayments_[i]] = unitPrices_[i];

            unchecked {
                ++i;
            }
        }

        emit TicketPricesUpdated(
            _msgSender(),
            typeId_,
            supportedPayments_,
            unitPrices_
        );
    }

    function supportedPayments(address payment_) external view returns (bool) {
        return __supportedPayments.get(payment_.fillLast96Bits());
    }

    function redeemTicket(
        address user_,
        address token_,
        uint256 value_,
        uint256 id_,
        uint256 type_
    ) external onlyRole(Roles.PROXY_ROLE) {
        Ticket memory ticket = __tickets[id_];

        if (ticket.account != address(0) || ticket.isUsed)
            revert Gacha__InvalidTicket();

        if (!__supportedPayments.get(token_.fillLast96Bits()))
            revert Gacha__InvalidPayment();

        if (!token_.supportsInterface(type(IERC721Upgradeable).interfaceId)) {
            uint256 unitPrice = IBKTreasury(vault()).priceOf(token_) *
                __unitPrices[type_][token_];
            if (unitPrice > value_) revert Gacha__InsufficientAmount();
        }

        ticket.account = user_;
        __tickets[id_] = ticket;

        emit Redeemed(user_, id_, type_);
    }

    function claimReward(
        address token_,
        uint256 ticketId_,
        uint256 value_,
        uint256 deadline_,
        bytes calldata signature_
    ) external whenNotPaused {
        if (deadline_ < block.timestamp) revert Gacha__Expired();
        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            __CLAIM_TYPE_HASH,
                            token_,
                            ticketId_,
                            value_,
                            deadline_,
                            _useNonce(bytes32(ticketId_))
                        )
                    ),
                    signature_
                )
            )
        ) revert Gacha__InvalidSignature();

        Ticket memory ticket = __tickets[ticketId_];

        if (ticket.isUsed) revert Gacha__PurchasedTicket();
        if (ticket.account == address(0)) revert Gacha__InvalidTicket();

        ticket.isUsed = true;

        __tickets[ticketId_] = ticket;

        if (token_.supportsInterface(type(IERC721Upgradeable).interfaceId))
            IBK721(token_).safeMint(ticket.account, value_);
        else
            IWithdrawableUpgradeable(vault()).withdraw(
                token_,
                ticket.account,
                value_,
                ""
            );

        emit Rewarded(_msgSender(), ticketId_, token_, value_);
    }

    function nonces(uint256 ticketId_) external view returns (uint256) {
        return _nonces[bytes32(ticketId_)];
    }

    function _beforeRecover(bytes memory) internal override whenPaused {}

    function _afterRecover(
        address,
        address,
        uint256,
        bytes memory
    ) internal override {}

    uint256[47] private __gap;
}