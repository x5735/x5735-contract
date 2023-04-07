// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

library LibSimpleFunctionRegistryRichErrors {
    // solhint-disable func-name-mixedcase

    function NotInRollbackHistoryError(bytes4 selector, address targetImpl)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("NotInRollbackHistoryError(bytes4,address)")),
                selector,
                targetImpl
            );
    }
}