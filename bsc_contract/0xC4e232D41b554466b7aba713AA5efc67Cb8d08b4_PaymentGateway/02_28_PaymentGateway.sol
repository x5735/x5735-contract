// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BitMaps} from "oz-custom/contracts/oz/utils/structs/BitMaps.sol";
import {
    ERC165Checker
} from "oz-custom/contracts/oz/utils/introspection/ERC165Checker.sol";
import {
    IERC721,
    ERC721TokenReceiver
} from "oz-custom/contracts/oz/token/ERC721/ERC721.sol";
import {
    IERC721Enumerable
} from "oz-custom/contracts/oz/token/ERC721/extensions/IERC721Enumerable.sol";

import {
    FundForwarder,
    IFundForwarder
} from "oz-custom/contracts/internal/FundForwarder.sol";

import {
    Roles,
    Manager,
    IAuthority
} from "oz-custom/contracts/presets/base/Manager.sol";

import {
    IWithdrawable
} from "oz-custom/contracts/internal/interfaces/IWithdrawable.sol";
import {
    IERC20,
    ITreasury,
    IERC20Permit,
    ICommandGate
} from "./interfaces/ICommandGate.sol";

import {Bytes32Address} from "oz-custom/contracts/libraries/Bytes32Address.sol";

contract PaymentGateway is
    Manager,
    ICommandGate,
    FundForwarder,
    ERC721TokenReceiver
{
    using ERC165Checker for address;
    using Bytes32Address for address;
    using BitMaps for BitMaps.BitMap;

    BitMaps.BitMap private __isWhitelisted;
    BitMaps.BitMap private __whitelistedVaults;

    constructor(
        IAuthority authority_,
        address[] memory vaults_
    ) payable Manager(authority_, 0) {
        _changeVault(IFundForwarder(address(authority_)).vault());
        __whitelistVaults(vaults_);
    }

    function changeVault(
        address vault_
    ) external override onlyRole(Roles.OPERATOR_ROLE) {
        _changeVault(vault_);
    }

    function whitelistVaults(
        address[] calldata vaults_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        __whitelistVaults(vaults_);
    }

    function updateTreasury(
        ITreasury treasury_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        _changeVault(address(treasury_));
    }

    function whitelistAddress(
        address addr_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        if (addr_ == _authority() || addr_ == vault())
            revert CommandGate__InvalidArgument();
        __isWhitelisted.set(addr_.fillLast96Bits());

        emit Whitelisted(addr_);
    }

    function depositNativeTokenWithCommand(
        address contract_,
        address vault_,
        bytes4 fnSig_,
        bytes calldata params_
    ) external payable whenNotPaused {
        address sender = _msgSender();
        __checkUser(sender);

        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert CommandGate__UnknownAddress(contract_);
        if (
            !(vault_ == vault() ||
                __whitelistedVaults.get(vault_.fillLast96Bits()))
        ) revert CommandGate__UnknownAddress(contract_);

        _safeNativeTransfer(vault_, msg.value, "");

        __executeTx(
            contract_,
            fnSig_,
            __concatDepositData(sender, address(0), msg.value, params_)
        );

        emit Commanded(
            contract_,
            fnSig_,
            params_,
            vault_,
            sender,
            address(0),
            msg.value
        );
    }

    function depositERC20WithCommand(
        IERC20 token_,
        uint256 value_,
        bytes4 fnSig_,
        address vault_,
        address contract_,
        bytes memory data_
    ) external whenNotPaused {
        address user = _msgSender();
        __checkUser(user);
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert CommandGate__UnknownAddress(contract_);
        if (
            !(vault_ == vault() ||
                __whitelistedVaults.get(vault_.fillLast96Bits()))
        ) revert CommandGate__UnknownAddress(vault_);

        _safeERC20TransferFrom(token_, user, vault_, value_);
        if (vault_ == vault())
            if (
                IWithdrawable(vault_).notifyERC20Transfer(
                    address(token_),
                    value_,
                    safeTransferHeader()
                ) != IWithdrawable.notifyERC20Transfer.selector
            ) revert CommandGate__ExecutionFailed();

        data_ = __concatDepositData(user, address(token_), value_, data_);
        __executeTx(contract_, fnSig_, data_);

        emit Commanded(
            contract_,
            fnSig_,
            data_,
            vault_,
            user,
            address(token_),
            value_
        );
    }

    function depositERC20PermitWithCommand(
        IERC20Permit token_,
        uint256 value_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes4 fnSig_,
        address vault_,
        address contract_,
        bytes memory data_
    ) external whenNotPaused {
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert CommandGate__UnknownAddress(contract_);
        if (
            !(vault_ == vault() ||
                __whitelistedVaults.get(vault_.fillLast96Bits()))
        ) revert CommandGate__UnknownAddress(vault_);

        address user = _msgSender();
        __checkUser(user);

        // move value from stack to memory to prevent stack too deep
        uint256 value = value_;
        token_.permit(user, address(this), value, deadline_, v, r, s);

        address token = address(token_);
        _safeERC20TransferFrom(IERC20(token), user, vault_, value);
        if (vault_ == vault())
            if (
                IWithdrawable(vault_).notifyERC20Transfer(
                    address(token_),
                    value_,
                    safeTransferHeader()
                ) != IWithdrawable.notifyERC20Transfer.selector
            ) revert CommandGate__ExecutionFailed();

        data_ = __concatDepositData(user, token, value, data_);
        __executeTx(contract_, fnSig_, data_);

        emit Commanded(contract_, fnSig_, data_, vault_, user, token, value);
    }

    function onERC721Received(
        address,
        address from_,
        uint256 tokenId_,
        bytes calldata data_
    ) external override whenNotPaused returns (bytes4) {
        _checkBlacklist(from_);
        (address target, address _vault, bytes4 fnSig, bytes memory data) = abi
            .decode(data_, (address, address, bytes4, bytes));

        if (!__isWhitelisted.get(target.fillLast96Bits()))
            revert CommandGate__UnknownAddress(target);
        if (
            !(_vault == vault() ||
                __whitelistedVaults.get(_vault.fillLast96Bits()))
        ) revert CommandGate__UnknownAddress(_vault);

        IERC721 nft = IERC721(_msgSender());
        nft.safeTransferFrom(
            address(this),
            _vault,
            tokenId_,
            safeTransferHeader()
        );

        __executeTx(
            target,
            fnSig,
            __concatDepositData(from_, address(nft), tokenId_, data)
        );

        emit Commanded(
            target,
            fnSig,
            data,
            _vault,
            from_,
            address(nft),
            tokenId_
        );

        return this.onERC721Received.selector;
    }

    function depositERC721MultiWithCommand(
        uint256[] calldata tokenIds_,
        IERC721[] calldata contracts_,
        bytes[] calldata data_
    ) external whenNotPaused {
        address sender = _msgSender();
        __checkUser(sender);
        uint256 length = tokenIds_.length;
        for (uint256 i; i < length; ) {
            contracts_[i].safeTransferFrom(
                sender,
                address(this),
                tokenIds_[i],
                data_[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function isVaultWhitelisted(address addr_) external view returns (bool) {
        return __whitelistedVaults.get(addr_.fillLast96Bits());
    }

    function isTargetWhitelisted(address addr_) external view returns (bool) {
        return __isWhitelisted.get(addr_.fillLast96Bits());
    }

    function __whitelistVaults(address[] memory vaults_) private {
        uint256 length = vaults_.length;
        uint256[] memory uintVaults;

        assembly {
            uintVaults := vaults_
        }

        for (uint256 i; i < length; ) {
            if (uintVaults[i] == 0) revert CommandGate__InvalidArgument();
            __whitelistedVaults.set(uintVaults[i]);
            unchecked {
                ++i;
            }
        }

        emit VaultsWhitelisted(vaults_);
    }

    function __executeTx(
        address target_,
        bytes4 fnSignature_,
        bytes memory params_
    ) private {
        (bool ok, ) = target_.call(abi.encodePacked(fnSignature_, params_));
        if (!ok) revert CommandGate__ExecutionFailed();
    }

    function __checkUser(address user_) private view {
        _checkBlacklist(user_);
        _onlyEOA(user_);
    }

    function __concatDepositData(
        address account_,
        address token_,
        uint256 value_,
        bytes memory data_
    ) private pure returns (bytes memory) {
        assembly {
            mstore(add(data_, 32), account_)
            mstore(add(data_, 64), token_)
            mstore(add(data_, 96), value_)
        }
        return data_;
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

    function safeRecoverHeader() public pure override returns (bytes memory) {
        /// @dev value is equal keccak256("SAFE_RECOVER_HEADER")
        return
            bytes.concat(
                bytes32(
                    0x556d79614195ebefcc31ab1ee514b9953934b87d25857902370689cbd29b49de
                )
            );
    }

    function safeTransferHeader() public pure override returns (bytes memory) {
        /// @dev value is equal keccak256("SAFE_TRANSFER")
        return
            bytes.concat(
                bytes32(
                    0xc9627ddb76e5ee80829319617b557cc79498bbbc5553d8c632749a7511825f5d
                )
            );
    }
}