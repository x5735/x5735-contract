// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../Libraries/Utils.sol";
import "../Interfaces/IPeripheralPool.sol";

contract EventDispatcher is Ownable {
	address public peripheralPool;
	address private SIGNER;

	event DispatchedIntent(bytes txHash, address fromAddress);

	mapping(bytes => bool) public signatureOracle;
	mapping(bytes => bool) public intentExecuted;

	function setSinger(address _singer) external onlyOwner {
		SIGNER = _singer;
	}

	constructor(address _peripheralPool) {
		peripheralPool = _peripheralPool;
	}

	function updatePeripheralPool(address _peripheralPool) external onlyOwner {
		peripheralPool = _peripheralPool;
	}

	function _isValidSigner(address signer) internal view returns (bool) {
		return signer == SIGNER;
	}

	function _isValidSignature(bytes32 messageHash, bytes memory signature) internal view {
		(address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(messageHash, signature);

		require(error == ECDSA.RecoverError.NoError, "ECOSA recover error");

		require(_isValidSigner(recovered), "SignerChecker: Invalid Signer");
	}

	function getParamsHash(Utils.Iparams memory params) public pure returns (bytes32) {
		return keccak256(abi.encode(params));
	}

	function executeIntent(Utils.Iparams memory params, bytes memory signature) external {
		require(!signatureOracle[signature], "signature already used");

		require(!intentExecuted[params.txHash], "intent already executed");

		require(params.chainID == block.chainid, "wrong chain");

		_isValidSignature(getParamsHash(params), signature);

		signatureOracle[signature] = true;

		intentExecuted[params.txHash] = true;

		IPeripheralPool(peripheralPool).transferTo(params.tokenAddress, params.fromAddress, params.amount);

		emit DispatchedIntent(params.txHash, params.fromAddress);
	}
}