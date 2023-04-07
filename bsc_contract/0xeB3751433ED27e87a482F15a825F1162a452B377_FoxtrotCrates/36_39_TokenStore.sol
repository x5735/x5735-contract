// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

import { CrateBundle, ICrateBundle } from "contracts/base/CrateBundle.sol";
import "contracts/base/lib/CurrencyTransferLib.sol";

import "contracts/base/interfaces/IERC1155Mintable.sol";
import "contracts/base/interfaces/IERC721Mintable.sol";

contract TokenStore is CrateBundle, ERC721HolderUpgradeable, ERC1155HolderUpgradeable {
	address private chainNativeTokenWrapper;

	function _setChainNativeTokenWrapperAddress(address newAddress) internal {
		chainNativeTokenWrapper = newAddress;
	}

	function _getChainNativeTokenWrapperAddress() internal view returns (address) {
		return chainNativeTokenWrapper;
	}

	/// @dev The address of the native token wrapper contract.
	function _storeTokens(
		address _tokenOwner,
		Token[] calldata _tokens,
		string memory _uriForTokens,
		uint256 _crateIdentifier,
		uint256[][] memory _probabilities,
		CrateType _crateType
	) internal {
		_createBundle(_tokens, _crateIdentifier, _probabilities, _crateType);
		_setUriOfBundle(_uriForTokens, _crateIdentifier);
		_handleSendCrateItemsToRequester(_tokenOwner, address(this), _tokens);
	}

	/**
	 * @dev Release all tokens in a bundle to a recipient.
	 * @param _recipient The address to release the tokens to.
	 * @param _crateId The ID of the bundle to release.
	 */
	function _releaseTokens(address _recipient, uint256 _crateId) internal {
		uint256 count = getTokenCountOfBundle(_crateId);
		Token[] memory tokensToRelease = new Token[](count);

		for (uint256 i; i < count; i++) {
			Token memory tempToken = getTokenOfBundle(_crateId, i);
			if (!tempToken.isMintRequired) {
				tokensToRelease[i] = tempToken;
			}
		}

		_deleteBundle(_crateId);

		_transferTokenBatch(address(this), _recipient, tokensToRelease);
	}

	/// @dev Transfers an arbitrary ERC20 / ERC721 / ERC1155 token.
	function _transferToken(address _from, address _to, Token memory _token) internal {
		require(chainNativeTokenWrapper != address(0), "FCCr: !ChW");

		if (_token.tokenType == TokenType.ERC20) {
			CurrencyTransferLib.transferCurrencyWithWrapper(
				_token.assetContract,
				_from,
				_to,
				_token.totalAmount,
				chainNativeTokenWrapper
			);
		} else if (_token.tokenType == TokenType.ERC721) {
			IERC721Mintable(_token.assetContract).safeTransferFrom(_from, _to, _token.tokenId);
		} else if (_token.tokenType == TokenType.ERC1155) {
			IERC1155Mintable(_token.assetContract).safeTransferFrom(
				_from,
				_to,
				_token.tokenId,
				_token.totalAmount,
				""
			);
		}
	}

	/**
	 * @dev Transfer or mint based on mintRequired flag.
	 * @param _from The address of the sender.
	 * @param _to The address of the recipient.
	 * @param _tokens The array of tokens to transfer.
	 */
	function _handleSendCrateItemsToRequester(
		address _from,
		address _to,
		Token[] memory _tokens
	) internal {
		Token[] memory transferableTokens = new Token[](_tokens.length);

		uint256[] memory ids = new uint256[](_tokens.length);
		uint256[] memory amounts = new uint256[](_tokens.length);

		uint256 transferableTokensCount;
		uint256 mintableTokensCount;

		for (uint256 i; i < _tokens.length; i++) {
			if (_tokens[i].isMintRequired) {
				ids[mintableTokensCount] = _tokens[i].tokenId;
				amounts[mintableTokensCount] = _tokens[i].totalAmount;
				mintableTokensCount += 1;
			} else {
				transferableTokens[transferableTokensCount] = _tokens[i];
				transferableTokensCount += 1;
				_transferToken(_from, _to, _tokens[i]);
			}
		}

		if (mintableTokensCount > 0) {
			IERC1155Mintable(_tokens[0].assetContract).mintBatch(_to, ids, amounts, "");
		}

		if (transferableTokensCount > 0) {
			_transferTokenBatch(_from, _to, transferableTokens);
		}
	}

	/// @dev Transfers multiple arbitrary ERC20 / ERC721 / ERC1155 tokens.
	function _transferTokenBatch(address _from, address _to, Token[] memory _tokens) internal {
		uint256 nativeTokenValue;

		for (uint256 i; i < _tokens.length; i++) {
			if (_tokens[i].assetContract == chainNativeTokenWrapper && _to == address(this)) {
				nativeTokenValue += _tokens[i].totalAmount;
			}
		}

		if (nativeTokenValue != 0) {
			Token memory _nativeToken = Token({
				assetContract: chainNativeTokenWrapper,
				tokenType: ICrateBundle.TokenType.ERC20,
				tokenId: 0,
				totalAmount: nativeTokenValue,
				isMintRequired: false,
				rarity: Rarity.NONE
			});
			_transferToken(_from, _to, _nativeToken);
		}
	}
}