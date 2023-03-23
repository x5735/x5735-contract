// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "../oz-upgradeable/proxy/utils/Initializable.sol";
import {
    ContextUpgradeable
} from "../oz-upgradeable/utils/ContextUpgradeable.sol";

import {
    IProtocolFeeUpgradeable
} from "./interfaces/IProtocolFeeUpgradeable.sol";

/**
 * @title ProtocolFeeUpgradeable
 * @dev Abstract contract for protocol fees.
 * @dev An implementation of this contract should define the `_percentageFraction` function, which returns the percentage fraction of the fee.
 * @dev The fee amount is calculated as the product of the fee percentage and the fee value.
 */
abstract contract ProtocolFeeUpgradeable is
    Initializable,
    ContextUpgradeable,
    IProtocolFeeUpgradeable
{
    FeeInfo public feeInfo;

    function __ProtocolFee_init(
        address token_,
        uint96 feeAmt_
    ) internal virtual onlyInitializing {
        __ProtocolFee_init_unchained(token_, feeAmt_);
    }

    function __ProtocolFee_init_unchained(
        address token_,
        uint96 feeAmt_
    ) internal virtual onlyInitializing {
        _setRoyalty(token_, feeAmt_);
    }

    /**
     * @dev Sets the royalty fee information
     * @param token_ Token address of the fee
     * @param amount_ Fee amount
     */
    function _setRoyalty(address token_, uint96 amount_) internal virtual {
        address sender = _msgSender();
        assembly {
            sstore(feeInfo.slot, or(shl(0xa0, amount_), token_))

            log4(
                0x00,
                0x00,
                /// @dev value is equal to keccak256("ProtocolFeeUpdated(address,address,uint256)")
                0x2e25af38da02ef39388b1eb731f19781b0bc2bd6d4eb7700732d0c0e6b910c67,
                sender,
                token_,
                amount_
            )
        }
    }

    /**
     * @dev Pure virtual function to return the percentage fraction of the fee
     * @return Percentage fraction of the fee
     */
    function _percentageFraction() internal pure virtual returns (uint256) {
        return 10_000;
    }

    uint256[49] private __gap;
}