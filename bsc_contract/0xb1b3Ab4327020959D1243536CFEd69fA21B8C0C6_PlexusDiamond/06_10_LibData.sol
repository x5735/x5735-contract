// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/Structs.sol";

library LibData {
    bytes32 internal constant BRIDGE_NAMESPACE = keccak256("diamond.standard.data.bridge");
    bytes32 internal constant STARGATE_NAMESPACE = keccak256("diamond.standard.data.stargate");

    struct BridgeData {
        mapping(bytes32 => BridgeInfo) transferInfo;
        mapping(bytes32 => bool) transfers;
    }

    struct StargateData {
        mapping(address => uint16) poolId;
        mapping(address => mapping(uint256 => uint16)) dstPoolId;
        mapping(uint256 => uint16) layerZeroId;
    }

    function bridgeStorage() internal pure returns (BridgeData storage ds) {
        bytes32 position = BRIDGE_NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    function stargateStorage() internal pure returns (StargateData storage s) {
        bytes32 position = STARGATE_NAMESPACE;
        assembly {
            s.slot := position
        }
    }

    function bridgeInfo(bytes32 tId, address srcToken, address toDstToken, uint64 chainId, uint256 amount, string memory bridge) internal {
        BridgeData storage bs = bridgeStorage();
        BridgeInfo memory tif = bs.transferInfo[tId];
        tif.dstToken = srcToken;
        tif.chainId = chainId;
        tif.amount = amount;
        tif.user = msg.sender;
        tif.bridge = bridge;
        bs.transferInfo[tId] = tif;

        emit Bridge(tif.user, tif.chainId, tif.dstToken, toDstToken, tif.amount, tId, tif.bridge);
    }

    event Bridge(address user, uint64 chainId, address srcToken, address toDstToken, uint256 fromAmount, bytes32 transferId, string bridge);

    event Swap(address user, address srcToken, address toToken, uint256 amount, uint256 returnAmount);

    event Relayswap(address receiver, address toToken, uint256 returnAmount);
}