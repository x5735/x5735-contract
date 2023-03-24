//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../WrappedToken.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/ITeleport.sol";
import "../interfaces/ITeleportDApp.sol";
import "../libraries/LibRouter.sol";

/**
 *  @notice Handles the bridging of ERC20 tokens
 */
contract RouterFacet is IRouter, ITeleportDApp {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    struct StateData {
        // ABridge chain Id
        uint8 chainId;
        // Address of the teleport to send transmissions to and to expect deliveries from
        address teleport;
        // Address to send collected fees in tokens 
        address feeTokenCollector;
        // Address of the entity that signs delivery estimations
        address deliveryAgent;
        // Teleport identifier of the ERC20 bridge
        bytes32 dAppId;
    }

    /**
     * @notice sets the state for the Router facet
     * @param data_ Abi encoded LibRouter.NativeCurrency and StateData
     * @dev This state method is never attached on the diamond
     */
    function state(bytes memory data_) external {
        LibRouter.Storage storage rs = LibRouter.routerStorage();

        (LibRouter.NativeCurrency memory nc, StateData memory data) 
            = abi.decode(data_, (LibRouter.NativeCurrency, StateData));

        rs.nativeCurrency = nc;
        rs.chainId = data.chainId;
        rs.teleport = data.teleport;
        rs.feeTokenCollector = data.feeTokenCollector;
        rs.deliveryAgent = data.deliveryAgent;
        rs.dAppId = data.dAppId;

        emit TeleportSet(rs.teleport);
    }

    /**
     *  @notice Send tokens to another chain via Teleport.
     *  @param targetChainId_ Our Abridge ID of the destination chain
     *  @param feeToken_ Address of the token the user is paying fee in
     *  @param token_ Address of the token to bridge, or address(0) if bridging native currency
     *  @param amount_ Amount of the bridged tokens
     *  @param receiver_ Address who will receive the tokens on the destination chain
     *  @param deliveryFeeData_ Object holding data necessary for deducting from msg.value to delivery agent
     *  @dev We determine the action for the ERC20 contract and build the appropriate payload
     *      bytes payload: {
     *          uint256 header, 
     *          bytes envelope: {
     *              bytes msg.sender, 
     *              bytes receiver, 
     *              bytes action: {
     *                  enum TargetAction,
     *                  bytes token,
     *                  bytes _lockMint() | _burnUnlock() | _burnMint()
     *              },
     *              uint256 deliveryFee
     *          }
     *      }
     */
    function egress(
        uint8 targetChainId_,
        address feeToken_,
        address token_,
        uint256 amount_,
        bytes calldata receiver_,
        DeliveryFeeData calldata deliveryFeeData_
    ) public override payable {
        LibRouter.Storage storage rs = LibRouter.routerStorage();
        bytes memory action;

        LibRouter.NativeTokenWithChainId memory nativeToken = wrappedToNativeToken(token_);
        if (nativeToken.chainId == 0) {
            emit LockMint(targetChainId_, token_, amount_, receiver_);

            action = abi.encode(
                    IRouter.TargetAction.Mint, _addressToBytes(token_),
                    _lockMint(token_, amount_)
                );
        }
        else if (nativeToken.chainId == targetChainId_) {
            emit BurnUnlock(targetChainId_, token_, amount_, receiver_);

            action = abi.encode(
                    IRouter.TargetAction.Unlock, nativeToken.contractAddress,
                    _burnUnlock(token_, amount_)
                );
        }
        else {
            emit BurnMint(targetChainId_, token_, amount_, receiver_);

            action = abi.encode(
                    IRouter.TargetAction.Mint, nativeToken.contractAddress,
                    _burnMint(nativeToken.chainId, token_, amount_)
                );
        }

        bytes memory payload = abi.encode(
                uint256(0), // current message header
                abi.encode( // envelope
                    _addressToBytes(msg.sender),
                    receiver_,
                    action,
                    deliveryFeeData_.fee
                )
            );

        if(deliveryFeeData_.fee > 0) {
            _collectDeliveryFee(
                targetChainId_,
                token_,
                amount_,
                receiver_,
                deliveryFeeData_.fee, 
                deliveryFeeData_.expiry,
                deliveryFeeData_.signature);
        }

        uint256 teleportFee = serviceFee();
        { 
            // stack too deep: let's scope the msg.value logic
            uint256 valueOwed = deliveryFeeData_.fee;

            if (feeToken_ != address(0)) {
                _collectFee(feeToken_);
            } else {
                valueOwed += teleportFee;
            }

            if (_isNativeCurrency(token_)) {
                valueOwed += amount_;
            }

            require(msg.value >= valueOwed, "Router: insufficient value");
        }
        bytes storage bridgeAddress = rs.bridgeAddressByChainId[targetChainId_];
        require(bridgeAddress.length > 0, "Router: unknown destination");

        ITeleport(rs.teleport).transmit{value: teleportFee}(
                targetChainId_, bridgeAddress, rs.dAppId,
                payload
            );
    }

     /**
     *  @notice Send tokens to another chain via Teleport using an using an EIP-2612 permit.
     *  @param targetChainId_ Our Abridge ID of the destination chain
     *  @param feeToken_ Address of the token the user is paying fee in
     *  @param token_ Address of the token to bridge, or address(0) if bridging native currency
     *  @param amount_ Amount of the bridged tokens
     *  @param receiver_ Address who will receive the tokens on the destination chain
     *  @param deliveryFeeData_ Object holding data necessary for deducting from msg.value to delivery agent
     *  @param deadline_ The deadline for the provided permit
     *  @param v_ The recovery id of the permit's ECDSA signature
     *  @param r_ The first output of the permit's ECDSA signature
     *  @param s_ The second output of the permit's ECDSA signature
     */
    function egressWithPermit(
        uint8 targetChainId_,
        address feeToken_,
        address token_,
        uint256 amount_,
        bytes calldata receiver_,
        DeliveryFeeData calldata deliveryFeeData_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external override payable {
        IERC2612Permit(token_).permit(msg.sender, address(this), amount_, deadline_, v_, r_, s_);
        egress(targetChainId_, feeToken_, token_, amount_, receiver_, deliveryFeeData_);
    }

    /**
     *  @param tokenAddress_ The address of the token contract
     *  @return Checks if the supplied token address is representing the native network currency
     */
    function _isNativeCurrency(address tokenAddress_) internal pure returns(bool) {
        return tokenAddress_ == address(0);
    }

    /**
     *  @param tokenAddress_ The ERC20 contract address, or address(0) if native currency
     *  @param amount_ Amount of the bridged tokens
     *  @return Payload for sending native tokens to a non-native chain
     *  @dev bytes payload: {uint256 amount, uint8 chainId, string tokenName, string tokenSymbol, uint8 tokenDecimals}
     */
    function _lockMint(address tokenAddress_, uint256 amount_) internal returns (bytes memory) {
        string memory tokenName;
        string memory tokenSymbol;
        uint8 decimals;
        if (_isNativeCurrency(tokenAddress_)) {
            LibRouter.NativeCurrency storage nc = LibRouter.routerStorage().nativeCurrency;
            tokenName = string(abi.encodePacked("Wrapped ", nc.name));
            tokenSymbol = string(abi.encodePacked("W", nc.symbol));
            decimals = nc.decimals;
        } else {
            tokenName = string(abi.encodePacked("Wrapped ", ERC20(tokenAddress_).name()));
            tokenSymbol = string(abi.encodePacked("W", ERC20(tokenAddress_).symbol()));
            decimals = ERC20(tokenAddress_).decimals();
            
            IERC20(tokenAddress_).safeTransferFrom(msg.sender, address(this), amount_); 
        }

        return abi.encode(amount_, LibRouter.routerStorage().chainId, tokenName, tokenSymbol, decimals);
    }

    /**
     *  @param tokenAddress_ The ERC20 contract address
     *  @param amount_ Amount of the bridged tokens
     *  @return Payload for sending non-native tokens to their native chain
     *  @dev bytes payload: {uint256 amount}
     */
    function _burnUnlock(address tokenAddress_, uint256 amount_) internal returns (bytes memory) {
        // we need to check if msg.sender owns what he wants to transfer (burn)
        WrappedToken(tokenAddress_).burnFrom(msg.sender, amount_);

        return abi.encode(amount_);
    }

    /**
     *  @param tokenAddress_ The ERC20 contract address
     *  @param nativeChainId_ Native Abridge chain id of the token
     *  @param amount_ Amount of the bridged tokens
     *  @return Payload for sending non-native tokens to a non-native chain
     *  @dev bytes payload: {uint256 amount, uint8 chainId, string tokenName, string tokenSymbol, uint8 tokenDecimals}
     */
    function _burnMint(uint8 nativeChainId_, address tokenAddress_, uint256 amount_) internal returns (bytes memory) {
        WrappedToken(tokenAddress_).burnFrom(msg.sender, amount_);

        return abi.encode(amount_, nativeChainId_, ERC20(tokenAddress_).name(), ERC20(tokenAddress_).symbol(), ERC20(tokenAddress_).decimals());
    }

    /**
     *  @notice Sends the signed amount of delivery fee to the delivery agent
     *  @param targetChainId_ Our Abridge ID of the destination chain
     *  @param token_ Address of the token to bridge
     *  @param amount_ Amount of the bridged tokens
     *  @param receiver_ Address who will receive the tokens on the destination chain
     *  @param deliveryFee_ Amount to deduct from msg.value and transfer to the delivery agent
     *  @param deliveryFeeExpiry_ Block after which the delivery fee signature should be considered invalid
     *  @param deliveryFeeSignature_ Deliver agent's signature for the delivery fee
     */
    function _collectDeliveryFee(
            uint8 targetChainId_,
            address token_,
            uint256 amount_,
            bytes calldata receiver_,
            uint256 deliveryFee_, 
            uint256 deliveryFeeExpiry_,
            bytes calldata deliveryFeeSignature_) 
        internal 
    {
        require(deliveryFeeExpiry_ >= block.number, "Router: delivery fee signature expired");

        LibRouter.Storage storage rs = LibRouter.routerStorage();

        address signer = ECDSA.recover(
            _computeDeliveryFeeHash(
                targetChainId_,
                token_,
                amount_,
                receiver_,
                deliveryFee_,
                deliveryFeeExpiry_
            ),
            deliveryFeeSignature_);

        require(signer == rs.deliveryAgent, "Router: invalid delivery fee signer/signature");

        rs.deliveryFeeNonces[msg.sender].increment();

        emit DeliveryFeeCollected(msg.sender, rs.deliveryAgent, deliveryFee_);

        (bool success, bytes memory returndata) = rs.deliveryAgent.call{value: deliveryFee_}("");
        require(success, string(returndata));
    }

    /// @notice Computes the bytes32 ethereum signed message hash of the delivery fee of an egress operation
    function _computeDeliveryFeeHash(
            uint8 targetChainId_,
            address token_,
            uint256 amount_,
            bytes calldata receiver_,
            uint256 deliveryFee_,
            uint256 deliveryFeeDeadline_) 
        internal view returns (bytes32) 
    {
        LibRouter.Storage storage rs = LibRouter.routerStorage();
        return ECDSA.toEthSignedMessageHash(keccak256(
            abi.encode(
                rs.chainId,
                targetChainId_,
                token_,
                amount_,
                msg.sender,
                receiver_,
                deliveryFee_,
                deliveryFeeDeadline_,
                rs.deliveryFeeNonces[msg.sender].current()
            )
        ));
    }

    /**
     *  @notice Send the fee amount in custom token to the fee token collector address
     *  @param feeToken_ Address of the token to bridge
     */
    function _collectFee(address feeToken_) internal {
        LibRouter.Storage storage rs = LibRouter.routerStorage();

        require(rs.feeTokenCollector != address(0), "Router: fee token collector address not set");
        
        uint256 feeOwed = rs.feeAmountByToken[feeToken_];
        require(feeOwed > 0, "Router: unsupported fee token");

        emit FeeTokensCollected(feeToken_, msg.sender, rs.feeTokenCollector, feeOwed);

        IERC20(feeToken_).safeTransferFrom(msg.sender, rs.feeTokenCollector, feeOwed);
    }

    /**
     *  @notice Receive tokens from another chain via Teleport.
     *  @param sourceChainId_ Abridge Chain ID the teleport message comes from
     *  @param transmissionSender_ Sender address of the teleport message
     *  @param dAppId_ dAppId for the teleport message
     *  @param payload_ Data payload of teleport message
     *  @dev header is a placeholder for future proofing
     */
    function onTeleportMessage(
            uint8 sourceChainId_, bytes calldata transmissionSender_,
            bytes32 dAppId_, bytes calldata payload_)
        external override
    {
        // Check message validity
        LibRouter.Storage storage rs = LibRouter.routerStorage();
        require(msg.sender == rs.teleport, "Router: unknown teleport");
        require(dAppId_ == rs.dAppId, "Router: unknown dAppId");
        require(keccak256(rs.bridgeAddressByChainId[sourceChainId_]) == keccak256(transmissionSender_), "Router: unknown sender");

        (uint256 header, bytes memory envelope) = abi.decode(payload_,
            (uint256, bytes));

        require(header == 0, "Router: unknown format");

        (bytes memory sender, bytes memory receiver, bytes memory action) = abi.decode(
            envelope, (bytes, bytes, bytes));

        require(sender.length > 0, "Router: should contain sender");

        // Decode the common action data
        (IRouter.TargetAction actionType, bytes memory nativeAddress, bytes memory actionData) = abi.decode(
            action, (IRouter.TargetAction, bytes, bytes));

        // and call the corresponding receive function
        if (actionType == IRouter.TargetAction.Unlock) {
            // with its specific payload
            (uint256 amount) = abi.decode(actionData, (uint256));
            _unlock(_bytesToAddress(nativeAddress), amount, _bytesToAddress(receiver));
        } else if (actionType == IRouter.TargetAction.Mint) {
            (uint256 amount, uint8 nativeChainId, string memory tokenName, string memory tokenSymbol, uint8 decimals) = abi.decode(
                actionData, (uint256, uint8, string, string, uint8));

            _mint(nativeAddress, amount, _bytesToAddress(receiver),
                nativeChainId, tokenName, tokenSymbol, decimals);
        } else {
            revert("Router: incorrect TargetAction");
        }
    }

    /**
     *  @notice Release previously locked native tokens.
     *  @param tokenAddress_ The ERC20 contract address, or address(0) if native currency
     *  @param amount_ Amount of the bridged tokens to be unlocked
     *  @param receiver_ The address to receive the tokens
     */
    function _unlock(address tokenAddress_, uint256 amount_, address receiver_) internal {
        emit Unlock(tokenAddress_, amount_, receiver_);
        if (_isNativeCurrency(tokenAddress_)) {
            (bool success, bytes memory returndata) = receiver_.call{value: amount_}("");
            require(success, string(returndata));
        } else {
            IERC20(tokenAddress_).safeTransfer(receiver_, amount_);
        }
    }

    /**
     *  @notice Mint wrapped versions of non-native tokens. Deploys a new token contract if necessary.
     *  @param nativeAddress_ The ERC20 contract address on the native chain
     *  @param amount_ Amount of the bridged tokens to be minted
     *  @param receiver_ The address to receive the tokens
     *  @param nativeChainId_ Our Abridge chain ID for the native network
     *  @param tokenName_ Name for the wrapped token
     *  @param tokenSymbol_ Symbol for the wrapped token
     *  @param decimals_ The number of decimals used to get the token's user representation
     */
    function _mint(bytes memory nativeAddress_, uint256 amount_, address receiver_,
            uint8 nativeChainId_, string memory tokenName_, string memory tokenSymbol_, uint8 decimals_)
        internal
    {
        address wrappedToken = nativeToWrappedToken(nativeChainId_, nativeAddress_);
        if (wrappedToken == address(0)) {
            wrappedToken = _deployWrappedToken(nativeChainId_, nativeAddress_, tokenName_, tokenSymbol_, decimals_);
        }

        emit Mint(wrappedToken, amount_, receiver_);

        WrappedToken(wrappedToken).mint(receiver_, amount_);
    }

    /**
     *  @notice Deploys a wrapped version of a native token to the current chain
     *  @param sourceChain_ Our Abridge chain ID for the native chain
     *  @param nativeToken_ ERC20 contract address on the native chain
     *  @param tokenName_ Name for the wrapped token
     *  @param tokenSymbol_ Symbol for the wrapped token
     *  @param decimals_ The number of decimals used to get the token's user representation
     */
    function _deployWrappedToken(
            uint8 sourceChain_, bytes memory nativeToken_,
            string memory tokenName_, string memory tokenSymbol_, uint8 decimals_)
        internal
        returns (address)
    {
        address createdContract;
        bytes32 salt = keccak256(abi.encode(sourceChain_, nativeToken_));
        bytes memory initCode = abi.encodePacked(type(WrappedToken).creationCode, abi.encode(tokenName_, tokenSymbol_, decimals_));
        assembly {
            createdContract := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        require(createdContract != address(0), "Router: target address occupied");

        LibRouter.setTokenMappings(sourceChain_, nativeToken_, createdContract);
        emit WrappedTokenDeployed(sourceChain_, nativeToken_, createdContract);

        return createdContract;
    }

    /**
     *  @param chainId_ Our Abridge chain ID for the native chain
     *  @param nativeToken_ ERC20 contract address on the native chain
     *  @return The address of the wrapped counterpart of `nativeToken` in the current chain
     */
    function nativeToWrappedToken(uint8 chainId_, bytes memory nativeToken_) public view override returns (address) {
        return LibRouter.routerStorage().nativeToWrappedToken[chainId_][nativeToken_];
    }

    /**
     *  @param wrappedToken_ ERC20 contract address of the wrapped token
     *  @return The chainId and address of the original token
     */
    function wrappedToNativeToken(address wrappedToken_) public view override returns (LibRouter.NativeTokenWithChainId memory) {
        return LibRouter.routerStorage().wrappedToNativeToken[wrappedToken_];
    }

    /**
     *  @return Required fee amount for bridging
     */
    function serviceFee() public view override returns (uint256) {
        return ITeleport(LibRouter.routerStorage().teleport).serviceFee();
    }

    /**
     *  @param addressAsBytes value of type bytes
     *  @return addr addressAsBytes value converted to type address
     */
    function _bytesToAddress(bytes memory addressAsBytes) internal pure returns (address addr) {
        require(addressAsBytes.length == 20, "Router: wrong address length");
        assembly {
            addr := mload(add(addressAsBytes, 20))
        }
    }

    /**
     *  @param addr value of type address
     *  @return addr value converted to type bytes
     */
    function _addressToBytes(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(addr);
    }

    /** 
     *  @param sender_ Address that initiates a bridging operation for which we collect delivery fee
     *  @return the current nonce for the sender_ address
     */
    function deliveryFeeNonce(address sender_) external view override returns (uint256) {
        return LibRouter.routerStorage().deliveryFeeNonces[sender_].current();
    }

}