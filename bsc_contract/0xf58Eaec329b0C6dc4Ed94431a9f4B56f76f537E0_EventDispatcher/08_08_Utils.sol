// SPDX-License-Identifier: AGPL-1.0

pragma solidity 0.8.17;

library Utils {
	struct Iparams {
		bytes txHash;
		uint256 chainID;
		address fromAddress;
		address toAddress;
		address tokenAddress;
		uint256 amount;
		uint256 value;
		bytes data;
	}
	struct IpramsSimulateTransaction {
		address toAddress;
		uint256 value;
		bytes data;
	}
}