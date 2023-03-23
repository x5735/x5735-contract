// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FundForwarder} from "oz-custom/contracts/internal/FundForwarder.sol";

import {ITreasury} from "oz-custom/contracts/presets/interfaces/ITreasury.sol";

import {
    ERC165Checker
} from "oz-custom/contracts/oz/utils/introspection/ERC165Checker.sol";

abstract contract BKFundForwarder is FundForwarder {
    using ERC165Checker for address;

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

    function _checkValidAddress(address vault_) internal view override {
        super._checkValidAddress(vault_);
        if (!vault_.supportsInterface(type(ITreasury).interfaceId))
            revert FundForwarder__InvalidArgument();
    }
}