// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

import { CrateBundleManager, ICrateBundleManager } from "contracts/base/CrateBundleManager.sol";

import "contracts/base/interfaces/IERC1155Mintable.sol";
import "contracts/base/interfaces/IERC721Mintable.sol";

contract TokenManager is CrateBundleManager, ERC721HolderUpgradeable, ERC1155HolderUpgradeable {
	
	/**
	 * @dev Transfers an arbitrary ERC20 / ERC721 / ERC1155 token.
	 * @param _from The address of the sender.
	 * @param _to The address of the recipient.
	 * @param _token The token to transfer.
	 */
	function _transferToken(address _from, address _to, Token memory _token) internal {
		if (_token.tokenType == TokenType.ERC721) {
			IERC721Mintable(_token.assetContract).safeTransferFrom(_from, _to, _token.tokenId);
		} else if (_token.tokenType == TokenType.ERC1155) {
			IERC1155Mintable(_token.assetContract).safeTransferFrom(
				_from,
				_to,
				_token.tokenId,
				_token.maxExistences,
				""
			);
		}
	}

	/**
	 * @dev Transfer or mint based on mintRequired flag.
	 * @param _to The address of the recipient.
	 * @param _tokens The array of tokens to transfer.
	 */
	function _handleSendCrateItemsToRequester(address _to, Token[] memory _tokens) internal {
		uint256[] memory ids = new uint256[](_tokens.length);
		uint256[] memory amounts = new uint256[](_tokens.length);

		uint256 mintableTokensCount;

		for (uint256 i; i < _tokens.length; i++) {
			ids[mintableTokensCount] = _tokens[i].tokenId;
			amounts[mintableTokensCount] = _tokens[i].maxExistences;
			mintableTokensCount += 1;
		}

		if (mintableTokensCount > 0) {
			IERC1155Mintable(_tokens[0].assetContract).mintBatch(_to, ids, amounts, "");
		}
	}
}