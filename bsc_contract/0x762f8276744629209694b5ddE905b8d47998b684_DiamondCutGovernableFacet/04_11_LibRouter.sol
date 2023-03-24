// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library LibRouter {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.router.storage");
    
    using EnumerableSet for EnumerableSet.AddressSet;

    struct NativeCurrency {
        // Name of the currency that's native to the deployment chain, e.g. Ether
        string name;
        // Symbol of the currency that's native to the deployment chain. e.g. ETH
        string symbol;
        // The number of symbols used for representation of the native currency
        uint8 decimals;
    }

    /// @notice Struct containing information about a token's address and its native chain
    struct NativeTokenWithChainId {
        // Native Abridge chain id
        uint8 chainId;
        // Token contract native address
        bytes contractAddress;
    }

    struct Storage {
        // Information about the deployment chain native currency
        NativeCurrency nativeCurrency;

        // Maps Abridge chainId => (nativeToken => wrappedToken)
        mapping(uint8 => mapping(bytes => address)) nativeToWrappedToken;

        // Maps wrapped tokens in the current chain to their native chain + token address
        mapping(address => NativeTokenWithChainId) wrappedToNativeToken;

        // Who is allowed to send us teleport messages by Abridge chain id
        mapping(uint8 => bytes) bridgeAddressByChainId;

        // How much should be paid for egress in a given token
        mapping(address => uint256) feeAmountByToken;

        // All tokens that we accept fee in
        EnumerableSet.AddressSet feeTokens;

        // Nonace used for delivery fee signatures
        mapping(address => Counters.Counter) deliveryFeeNonces;

        // The Abridge chainId of the current chain
        uint8 chainId;

        // Address of the teleport contract to send/receive transmissions to/from
        address teleport;

        // Address to collect delivery fees for while performing egress
        address deliveryAgent;

        // Address to send egress collected fee if it is paid in tokens, not coins
        address feeTokenCollector;

        // Messaging Protocol (Teleport) Identifier of the ERC20 bridge
        bytes32 dAppId;
    }

    /// @notice Adds, updates or removes an accepted fee token
    function setFeeToken(address feeToken_, uint256 amount_) internal {
        Storage storage rs = routerStorage();

        rs.feeAmountByToken[feeToken_] = amount_;
        if(amount_ != 0) {
            rs.feeTokens.add(feeToken_);
        } else {
            rs.feeTokens.remove(feeToken_);
        }
    }

    /// @notice sets the wrapped to native token mapping
    function setTokenMappings(uint8 sourceChain_, bytes memory nativeToken_, address deployedToken) internal {
        Storage storage rs = routerStorage();
        rs.nativeToWrappedToken[sourceChain_][nativeToken_] = deployedToken;
        NativeTokenWithChainId storage wrappedToNative = rs.wrappedToNativeToken[deployedToken];
        wrappedToNative.chainId = sourceChain_;
        wrappedToNative.contractAddress = nativeToken_;
    }

    function routerStorage() internal pure returns (Storage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}