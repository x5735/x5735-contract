// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

library LibProxyRichErrors {
    // solhint-disable func-name-mixedcase

    function NotImplementedError(bytes4 selector)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("NotImplementedError(bytes4)")),
                selector
            );
    }

    function InvalidBootstrapCallerError(address actual, address expected)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(
                    keccak256("InvalidBootstrapCallerError(address,address)")
                ),
                actual,
                expected
            );
    }

    function InvalidDieCallerError(address actual, address expected)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("InvalidDieCallerError(address,address)")),
                actual,
                expected
            );
    }

    function BootstrapCallFailedError(address target, bytes memory resultData)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                bytes4(keccak256("BootstrapCallFailedError(address,bytes)")),
                target,
                resultData
            );
    }
}