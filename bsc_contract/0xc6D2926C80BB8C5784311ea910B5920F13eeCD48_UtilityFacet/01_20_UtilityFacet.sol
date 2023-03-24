//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "../libraries/LibRouter.sol";
import "../libraries/LibDiamond.sol";

import "../WrappedToken.sol";
import "../Governable.sol";

import "../interfaces/IUtility.sol";

contract UtilityFacet is IUtility, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    /**
     * @notice Calls the state functions of other diamond facets
     * @dev This state method is never attached on the diamond.
     * This method is to be delegatecall-ed from diamondCutGovernableFacet.diamondCut
     * and takes as parameter the encoded call data for the state methods of any other diamond facets.
     */
    function state(bytes memory data_) external {
        (IUtility.Subroutine[] memory subroutines) = abi.decode(data_,
            (IUtility.Subroutine[]));

        for (uint256 i = 0; i < subroutines.length;) {
            // callParams is abi.encodeWithSignature("init(bytes)", _bytes)
            LibDiamond.initializeDiamondCut(subroutines[i].contractAddress, subroutines[i].callParams);
            unchecked { i += 1; }
        }
    }

    /**
     *  @notice Pauses a given token contract
     *  @param tokenAddress_ The token contract
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function pauseToken(address tokenAddress_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeTokenActionMessage(IUtility.TokenAction.Pause, tokenAddress_), signatures_)
    {
        emit TokenPaused(msg.sender, tokenAddress_);
        WrappedToken(tokenAddress_).pause();
    }

    /**
     *  @notice Unpauses a given token contract
     *  @param tokenAddress_ The token contract
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function unpauseToken(address tokenAddress_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeTokenActionMessage(IUtility.TokenAction.Unpause, tokenAddress_), signatures_)
    {
        emit TokenUnpaused(msg.sender, tokenAddress_);
        WrappedToken(tokenAddress_).unpause();
    }

    /**
     *  @param _action denotes pause or unpause
     *  @param _tokenAddress The token address
     *  @return Hash message represeting the pause/unpause token operation
     */
    function computeTokenActionMessage(IUtility.TokenAction _action, address _tokenAddress) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeTokenActionMessage",
                uint8(_action), _tokenAddress,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @notice Adds an existing token contract to use as a WrappedToken
     *  @param nativeChainId_ The native Abridge chain id for the token
     *  @param nativeToken_ The address in the native network
     *  @param wrappedToken_ The wrapped token address in this network
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function setWrappedToken(uint8 nativeChainId_, bytes calldata nativeToken_, address wrappedToken_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeSetWrappedTokenMessage(nativeChainId_, nativeToken_, wrappedToken_), signatures_)
    {
        require(wrappedToken_ != address(0), "Wrapped token address must be non-zero");
        LibRouter.setTokenMappings(nativeChainId_, nativeToken_, wrappedToken_);
        emit WrappedTokenSet(nativeChainId_, nativeToken_, wrappedToken_);
    }

    /**
     *  @notice Computes the Eth signed message to use for extracting signature signers for toggling a token state
     *  @param nativeChainId_ The native Abridge chain id for the token
     *  @param nativeToken_ The address in the native network
     *  @param wrappedToken_ The wrapped token address in this network
     */
    function computeSetWrappedTokenMessage(uint8 nativeChainId_, bytes calldata nativeToken_, address wrappedToken_)
        internal view returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetWrappedTokenMessage",
                nativeChainId_, nativeToken_, wrappedToken_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @notice Removes a wrapped-native token pair from the bridge
     *  @param wrappedToken_ The wrapped token address in this network
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function unsetWrappedToken(address wrappedToken_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeUnsetWrappedTokenMessage(wrappedToken_), signatures_)
    {
        LibRouter.Storage storage rs = LibRouter.routerStorage();
        delete rs.nativeToWrappedToken[rs.wrappedToNativeToken[wrappedToken_].chainId][rs.wrappedToNativeToken[wrappedToken_].contractAddress];
        delete rs.wrappedToNativeToken[wrappedToken_];
        emit WrappedTokenUnset(wrappedToken_);
    }

    /**
     *  @notice Computes the Eth signed message to use for extracting signature signers for toggling a token state
     *  @param wrappedToken_ The wrapped token address in this network
     */
    function computeUnsetWrappedTokenMessage(address wrappedToken_)
        internal view returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeUnsetWrappedTokenMessage",
                wrappedToken_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @notice Set the allowed state for the specified teleport senders
     *  @param senders_ Array of chainId and sender
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function setTeleportSenders(TeleportSender[] calldata senders_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeSetTeleportSenders(senders_), signatures_)
    {
        LibRouter.Storage storage rs = LibRouter.routerStorage();
        for (uint256 i = 0; i < senders_.length;) {
            rs.bridgeAddressByChainId[senders_[i].chainId] = senders_[i].senderAddress;
            unchecked { i += 1; }
        }

        emit TeleportSenderSet(senders_);
    }

    /**
     *  @param senders_ Array of chainId and sender
     *  @return Hash message represeting the setTeleportSenders operation
     */
    function computeSetTeleportSenders(TeleportSender[] calldata senders_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetTeleportSenders",
                senders_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @return Get the bridge dAppId
     */
    function dappId() external view override returns (bytes32) {
        return LibRouter.routerStorage().dAppId;
    }

    /**
     *  @notice Set the bridge dAppId
     *  @param dappId_ the bridge dAppId to set
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function setDappId(bytes32 dappId_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeSetDappId(dappId_), signatures_)
    {
        LibRouter.routerStorage().dAppId = dappId_;

        emit DappIdSet(dappId_);
    }

    /**
     *  @param dappId_ dAppId hash
     *  @return Hash message represeting the setDappId operation
     */
    function computeSetDappId(bytes32 dappId_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetDappId",
                dappId_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }


    /**
     *  @notice Adds, updates or removes an accepted fee token
     *  @param feeToken_ Address of the fee token to change
     *  @param amount_ New amount to set; if 0 the token will no longer be accepted for paying fees
     */
    function setFeeToken(address feeToken_, uint256 amount_, bytes[] calldata signatures_) 
        external override 
        onlyConsensusNonce(computeSetFeeToken(feeToken_, amount_), signatures_)
    {
        LibRouter.setFeeToken(feeToken_, amount_);
        emit FeeTokenSet(feeToken_, amount_);
    }

    /**
     *  @param feeToken_ Address of the fee token to change
     *  @param amount_ New amount to set
     *  @return Hash message represeting the setFeeToken operation
     */
    function computeSetFeeToken(address feeToken_, uint256 amount_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetFeeToken",
                feeToken_, amount_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @param feeToken_ Address of the fee token to look-up
     *  @return The fee amount in the given token
     */
    function feeAmountByToken(address feeToken_) external view override returns(uint256)  {
        return LibRouter.routerStorage().feeAmountByToken[feeToken_];
    }
    
    /**
     *  @return The addresses of all accepted fee tokens
     */
    function feeTokens() external view override returns(address[] memory) {
        return LibRouter.routerStorage().feeTokens.values();
    }

    /**
     *  @return Get the address that will collect fees in custom tokens
     */
    function feeTokenCollector() external view override returns (address) {
        return LibRouter.routerStorage().feeTokenCollector;
    }

    /**
     *  @notice Set the address that will collect fees in custom tokens
     *  @param feeTokenCollector_ the address to send fee tokens to
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function setFeeTokenCollector(address feeTokenCollector_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeSetFeeTokenCollector(feeTokenCollector_), signatures_)
    {
        LibRouter.routerStorage().feeTokenCollector = feeTokenCollector_;

        emit FeeTokenCollectorSet(feeTokenCollector_);
    }

    /**
     *  @param feeTokenCollector_ the address to send fee tokens to
     *  @return Hash message represeting the setFeeTokenCollector operation
     */
    function computeSetFeeTokenCollector(address feeTokenCollector_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetFeeTokenCollector",
                feeTokenCollector_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }

    /**
     *  @return Get the address of the agent that will receive funds for completing a bridging operation
     */
    function deliveryAgent() external view override returns (address) {
        return LibRouter.routerStorage().deliveryAgent;
    }

    /**
     *  @notice Set the address of the agent that will receive funds for completing a bridging operation
     *  @param deliveryAgent_ the address of the agent that will receive funds for completing a bridging operation
     *  @param signatures_ The array of signatures from the members, authorising the operation
     */
    function setDeliveryAgent(address deliveryAgent_, bytes[] calldata signatures_)
        external override
        onlyConsensusNonce(computeSetDeliveryAgent(deliveryAgent_), signatures_)
    {
        LibRouter.routerStorage().deliveryAgent = deliveryAgent_;

        emit DeliveryAgentSet(deliveryAgent_);
    }

    /**
     *  @param deliveryAgent_ the address of the agent that will receive funds for completing a bridging operation
     *  @return Hash message represeting the setDeliveryAgent operation
     */
    function computeSetDeliveryAgent(address deliveryAgent_) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                LibRouter.routerStorage().chainId, "computeSetDeliveryAgent",
                deliveryAgent_,
                LibGovernance.governanceStorage().administrativeNonce.current())
            )
        );
    }
}