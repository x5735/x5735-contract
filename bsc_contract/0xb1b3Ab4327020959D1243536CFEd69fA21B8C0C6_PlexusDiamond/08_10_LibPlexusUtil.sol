// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapFailed} from "../Errors/GenericErrors.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/Structs.sol";
import "./LibDiamond.sol";
import "./LibData.sol";

library LibPlexusUtil {
    using SafeERC20 for IERC20;
    IERC20 private constant NATIVE_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /// @notice Determines whether the given address is the zero address
    /// @param addr The address to verify
    /// @return Boolean indicating if the address is the zero address
    function isZeroAddress(address addr) internal pure returns (bool) {
        return addr == address(0);
    }

    function getBalance(address token) internal view returns (uint256) {
        return token == address(NATIVE_ADDRESS) ? address(this).balance : IERC20(token).balanceOf(address(this));
    }

    function userBalance(address user, address token) internal view returns (uint256) {
        return token == address(NATIVE_ADDRESS) ? user.balance : IERC20(token).balanceOf(user);
    }

    function _isNative(address _token) internal pure returns (bool) {
        return (IERC20(_token) == NATIVE_ADDRESS);
    }

    function _isTokenDeposit(address _token, uint256 _amount) internal returns (bool isNotNative) {
        isNotNative = !_isNative(_token);

        if (isNotNative) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    function _tokenDepositAndSwap(SwapData calldata _swap) internal returns (uint256) {
        SwapData calldata swapData = _swap;
        _isTokenDeposit(swapData.srcToken, swapData.amount);
        uint256 dstAmount = _swapStart((swapData));
        return dstAmount;
    }

    function _tokenDepositAndUserSwap(SwapData calldata _swap) internal returns (uint256) {
        SwapData calldata swapData = _swap;
        _isTokenDeposit(swapData.srcToken, swapData.amount);
        uint256 dstAmount = _userSwapStart((swapData));
        return dstAmount;
    }

    function _swapStart(SwapData calldata swapData) internal returns (uint256 dstAmount) {
        SwapData calldata swap = swapData;
        bool isNotNative = !_isNative(swap.srcToken);
        if (isNotNative) {
            IERC20(swap.srcToken).approve(swap.swapRouter, swap.amount);
        }
        uint256 initDstTokenBalance = getBalance(swap.dstToken);
        (bool succ, ) = swap.swapRouter.call{value: isNotNative ? 0 : swap.amount}(swap.callData);
        if (succ) {
            uint256 dstTokenBalance = getBalance(swap.dstToken);
            dstAmount = dstTokenBalance > initDstTokenBalance ? dstTokenBalance - initDstTokenBalance : dstTokenBalance;
            emit LibData.Swap(swap.user, swap.srcToken, swap.dstToken, swap.amount, dstAmount);
        } else {
            revert SwapFailed();
        }
    }

    function _userSwapStart(SwapData calldata swapData) internal returns (uint256 dstAmount) {
        SwapData calldata swap = swapData;
        bool isNotNative = !_isNative(swap.srcToken);
        if (isNotNative) {
            IERC20(swap.srcToken).approve(swap.swapRouter, swap.amount);
        }
        uint256 initDstTokenBalance = userBalance(swap.user, swap.dstToken);
        (bool succ, ) = swap.swapRouter.call{value: isNotNative ? 0 : swap.amount}(swap.callData);
        if (succ) {
            uint256 dstTokenBalance = userBalance(swap.user, swap.dstToken);
            dstAmount = dstTokenBalance > initDstTokenBalance ? dstTokenBalance - initDstTokenBalance : dstTokenBalance;
            emit LibData.Swap(swap.user, swap.srcToken, swap.dstToken, swap.amount, dstAmount);
        } else {
            revert SwapFailed();
        }
    }

    function _safeNativeTransfer(address to_, uint256 amount_) internal {
        (bool sent, ) = to_.call{value: amount_}("");
        require(sent, "Safe safeTransfer fail");
    }

    function _fee(address dstToken, uint256 dstAmount) internal returns (uint256 returnAmount) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 getFee = (dstAmount * ds.fee) / 10000;
        returnAmount = dstAmount - getFee;
        if (getFee > 0) {
            if (!_isNative(dstToken)) {
                IERC20(dstToken).safeTransfer(ds.contractOwner, getFee);
            } else {
                _safeNativeTransfer(ds.contractOwner, getFee);
            }
        }
    }
}