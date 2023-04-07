// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MultiSigOwner.sol";

contract Treasurer is MultiSigOwner {
    string public constant treasurer = "Treasurer";
    struct Call {
        address target;
        bytes callData;
    }
    struct Result {
        bool success;
        bytes returnData;
    }

    receive() external payable {}

    function _tryAggregate(
        bool requireSuccess,
        Call[] memory calls
    ) internal returns (Result[] memory returnData) {
        uint256 callLength = calls.length;
        returnData = new Result[](callLength);
        for (uint256 i = 0; i < callLength; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );

            if (requireSuccess) {
                require(success, "MultiSigOwner: call failed");
            }

            returnData[i] = Result(success, ret);
        }
    }

    function aggregate(
        Call[] memory calls,
        bytes memory signData,
        bytes memory keys
    )
        public
        validSignOfOwner(signData, keys, "aggregate")
        returns (Result[] memory returnData)
    {
        returnData = _tryAggregate(true, calls);
    }

    function tryAggregate(
        bool requireSuccess,
        Call[] memory calls,
        bytes memory signData,
        bytes memory keys
    )
        public
        validSignOfOwner(signData, keys, "tryAggregate")
        returns (Result[] memory returnData)
    {
        returnData = _tryAggregate(requireSuccess, calls);
    }
}