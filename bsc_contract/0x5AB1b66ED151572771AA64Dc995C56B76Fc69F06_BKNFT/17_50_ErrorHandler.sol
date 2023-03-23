// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

error ErrorHandler__ExecutionFailed();

library ErrorHandler {
    function handleRevertIfNotSuccess(
        bool ok_,
        bytes memory revertData_
    ) internal pure {
        assembly {
            if iszero(ok_) {
                let revertLength := mload(revertData_)
                if iszero(iszero(revertLength)) {
                    // Start of revert data bytes. The 0x20 offset is always the same.
                    revert(add(revertData_, 0x20), revertLength)
                }

                //  revert ErrorHandler__ExecutionFailed()
                mstore(0x00, 0xa94eec76)
                revert(0x1c, 0x04)
            }
        }
    }
}