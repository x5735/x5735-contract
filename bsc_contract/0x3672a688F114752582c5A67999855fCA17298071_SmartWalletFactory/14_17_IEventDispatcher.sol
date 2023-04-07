// SPDX-License-Identifier: AGPL-1.0

pragma solidity 0.8.17;

import "../Libraries/Utils.sol";

interface IEventDispatcher {
	function executeIntent(Utils.Iparams memory params, bytes memory signature) external;
}