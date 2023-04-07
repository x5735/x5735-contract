// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "contracts/FoxtrotCrates.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FoxtrotCratesV2 is Initializable, FoxtrotCrates {
	
	uint32 private constant CALLBACKGASLIMIT = 300_000;

	function initialize() public initializer {
		__Ownable_init();
	}

	/**
	 * @dev Open a crate by rarity
	 * @param _crateId The crate id to open
	 * @param _amountToOpen The amount of crates to open
	 * @return uint256 The request id
	 */
	function openCrateV2(
		uint256 _crateId,
		uint256 _amountToOpen
	) external virtual returns (uint256) {
		require(CrateBundleManager.getProbabilityOfCrate(_crateId).length != 0, "FCCr: !PRC");
		uint32 requestedRandoms = 2;
		return
			_requestOpenCrate(
				CrateType.RARITY_CRATE,
				_crateId,
				_amountToOpen,
				requestedRandoms,
				CALLBACKGASLIMIT,
				false
			);
	}

	/**
	 * @dev Open a crate by rarity
	 * @param _crateId The crate id to open
	 * @param _amountToOpen The amount of crates to open
	 * @param _callBackGasLimit The amount of gas to use during the claiming
	 * @return uint256 The request id
	 */
	function openCrateAndClaimRewardsV2(
		uint256 _crateId,
		uint256 _amountToOpen,
		uint32 _callBackGasLimit
	) external returns (uint256) {
		require(CrateBundleManager.getProbabilityOfCrate(_crateId).length != 0, "FCCr: !PRC");
		uint32 requestedRandoms = 2;
		return
			_requestOpenCrate(
				CrateType.RARITY_CRATE,
				_crateId,
				_amountToOpen,
				requestedRandoms,
				_callBackGasLimit,
				true
			);
	}

}