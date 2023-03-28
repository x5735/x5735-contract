// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../BasePaymaster.sol";
import "../EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./CrescentWalletProxy.sol";

contract CrescentPaymaster is BasePaymaster, Initializable {

    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    address public verifyingSigner;

    address public walletController;

    address public dkimManager;

    address public dkimVerifier;

    bytes32 public crescentWallet;

    mapping (address => bool) private supportWallets;

    mapping (bytes32 => address) private wallets;

    constructor(EntryPoint _entryPoint) BasePaymaster(_entryPoint) {}

    function initialize(address _entryPoint, address _walletController, address _dkimManager, address _dkimVerifier, address _verifyingSigner) external initializer {
        _transferOwnership(_msgSender());
        entryPoint = EntryPoint(payable(_entryPoint));

        verifyingSigner = _verifyingSigner;
        crescentWallet = _crescentWallet();
        walletController = _walletController;
        dkimManager = _dkimManager;
        dkimVerifier = _dkimVerifier;
    }

    function setVerifyingSigner(address _verifyingSigner) public onlyOwner {
        require(verifyingSigner != _verifyingSigner);
        verifyingSigner = _verifyingSigner;
    }

    function setWalletController(address _walletController) public onlyOwner {
        require(walletController != _walletController);
        walletController = _walletController;
    }

    function setDKIMManger(address _dkimManager) public onlyOwner {
        require(dkimManager != _dkimManager);
        dkimManager = _dkimManager;
    }

    function _crescentWallet() internal view virtual returns (bytes32) {
        return keccak256(type(CrescentWalletProxy).creationCode);
    }

    function getCrescentWalletProxy() public view virtual returns (bytes memory) {
        return type(CrescentWalletProxy).creationCode;
    }

    function getWallet(bytes32 salt) public view returns (address) {
        return wallets[salt];
    }

    function supportWallet(address wallet) public view returns (bool) {
        return supportWallets[wallet];
    }

    /**
     * return the hash we're going to sign off-chain (and validate on-chain)
     * this method is called by the off-chain service, to sign the request.
     * it is called on-chain from the validatePaymasterUserOp, to validate the signature.
     * note that this signature covers all fields of the UserOperation, except the "paymasterData",
     * which will carry the signature itself.
     */
    function getHash(UserOperation calldata userOp)
    public pure returns (bytes32) {
        //can't use userOp.hash(), since it contains also the paymasterData itself.
        return keccak256(abi.encode(
                userOp.getSender(),
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGas,
                userOp.verificationGas,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                userOp.paymaster
            ));
    }

    /**
     * verify our external signer signed this request.
     * the "paymasterData" is supposed to be a signature over the entire request params
     */
    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*requestId*/, uint256 requiredPreFund)
    external view override returns (bytes memory context) {
        (requiredPreFund);

        _validateConstructor(userOp);

        bytes32 hash = getHash(userOp);
        uint256 sigLength = userOp.paymasterData.length;
        require(sigLength == 64 || sigLength == 65, "CrescentPaymaster: invalid signature length in paymasterData");
        require(verifyingSigner == hash.toEthSignedMessageHash().recover(userOp.paymasterData), "CrescentPaymaster: wrong signature");

        //no need for other on-chain validation: entire UserOp should have been checked
        // by the external service prior to signing it.
        if (userOp.initCode.length > 0) {
            return abi.encode(bytes32(userOp.nonce), userOp.getSender());
        }
        return "";
    }

    function _validateConstructor(UserOperation calldata userOp) internal virtual view {
        if (userOp.initCode.length == 0) {
            return;
        }
        bytes32 bytecodeHash = keccak256(userOp.initCode[0 : userOp.initCode.length - 128]);
        require(crescentWallet == bytecodeHash, "CrescentPaymaster: unknown wallet constructor");

        bytes32 entryPointParam = bytes32(userOp.initCode[userOp.initCode.length - 128 :]);
        require(address(uint160(uint256(entryPointParam))) == address(entryPoint), "wrong entryPoint in constructor");

        bytes32 walletControllerParam = bytes32(userOp.initCode[userOp.initCode.length - 96 :]);
        require(address(uint160(uint256(walletControllerParam))) == walletController, "wrong wallet controller in constructor");

        bytes32 dkimParam = bytes32(userOp.initCode[userOp.initCode.length - 64 :]);
        require(address(uint160(uint256(dkimParam))) == dkimManager, "wrong dkim manager in constructor");

        bytes32 dkimVerifierParam = bytes32(userOp.initCode[userOp.initCode.length - 32 :]);
        require(address(uint160(uint256(dkimVerifierParam))) == dkimVerifier, "wrong dkim verifier in constructor");
    }

    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (wallet pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        (mode);
        (actualGasCost);
        if (context.length == 64) {
            bytes32 hmua = bytes32(context);
            address sender = address(uint160(uint256(bytes32(context[32:]))));
            wallets[hmua] = sender;
            supportWallets[sender] = true;
        }
    }
}