//SPDX-License-Identifier: UXUY
pragma solidity ^0.8.11;

import "./CommonBase.sol";
import "../interfaces/IBridgeAdapter.sol";
import "../libraries/SafeNativeAsset.sol";
import "../libraries/SafeERC20.sol";

abstract contract AdapterBase is CommonBase {
    using SafeNativeAsset for address;
    using SafeERC20 for IERC20;

    event Refunded(address indexed recipient, address token, uint amount);

    modifier refundUnused(address tokenIn) {
        _;
        if (tokenIn.isNativeAsset()) {
            uint balance = address(this).balance;
            if (balance > 0) {
                tx.origin.safeTransfer(balance);
                emit Refunded(tx.origin, SafeNativeAsset.nativeAsset(), balance);
            }
        } else {
            uint balance = IERC20(tokenIn).balanceOf(address(this));
            if (balance > 0) {
                IERC20(tokenIn).safeTransfer(tx.origin, balance);
                emit Refunded(tx.origin, tokenIn, balance);
            }
        }
    }
}