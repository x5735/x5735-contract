//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "../SmartWallet/SmartWallet.sol";

contract SmartWalletFactory {
	mapping(address => address) public wallets;

	event ContractCreated(bytes txHash, address owner, address SmartWallet);

	function deploySmartWallet(bytes memory txHash, address owner, address secureExecutor) external {
		SmartWallet wallet = new SmartWallet(owner, secureExecutor);

		wallets[owner] = address(wallet);

		emit ContractCreated(txHash, owner, address(wallet));
	}
}