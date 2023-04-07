// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

library LibOwnableRichErrors {
    // solhint-disable func-name-mixedcase

    function OnlyOwnerError(address sender, address owner)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("OnlyOwnerError(address,address)")),
                sender,
                owner
            );
    }

    function OnlyAdminError(address sender, address admin)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("OnlyAdminError(address,address)")),
                sender,
                admin
            );
    }

    function TransferOwnerToZeroError() internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("TransferOwnerToZeroError()"))
            );
    }

    function MigrateCallFailedError(address target, bytes memory resultData)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("MigrateCallFailedError(address,bytes)")),
                target,
                resultData
            );
    }
}