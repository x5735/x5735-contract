// SPDX-License-Identifier: AGPL-1.0

pragma solidity 0.8.17;

import "../Libraries/Utils.sol";

interface IPeripheralPool {
	function transferTo(address tokenAddress, address toAddress, uint256 amount) external;
}