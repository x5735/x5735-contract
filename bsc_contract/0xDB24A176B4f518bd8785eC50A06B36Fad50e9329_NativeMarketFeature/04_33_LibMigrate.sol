// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "../lib_bytes4/LibRichErrorsV06.sol";
import "../errors/LibOwnableRichErrors.sol";

library LibMigrate {
    /// @dev Magic bytes returned by a migrator to indicate success.
    ///      This is `keccack('MIGRATE_SUCCESS')`.
    bytes4 internal constant MIGRATE_SUCCESS = 0x2c64c5ef;

    using LibRichErrorsV06 for bytes;

    /// @dev Perform a delegatecall and ensure it returns the magic bytes.
    /// @param target The call target.
    /// @param data The call data.
    function delegatecallMigrateFunction(address target, bytes memory data)
        internal
    {
        (bool success, bytes memory resultData) = target.delegatecall(data);
        if (
            !success ||
            resultData.length != 32 ||
            abi.decode(resultData, (bytes4)) != MIGRATE_SUCCESS
        ) {
            LibOwnableRichErrors
                .MigrateCallFailedError(target, resultData)
                .rrevert();
        }
    }
}