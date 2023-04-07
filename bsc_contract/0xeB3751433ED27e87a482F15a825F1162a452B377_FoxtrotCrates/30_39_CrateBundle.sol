// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "contracts/base/interfaces/ICrateBundle.sol";
import "contracts/base/lib/CurrencyTransferLib.sol";

interface IERC165 {
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 *  @title   Token Bundle
 *  @notice  `CrateBundle` contract extension allows bundling-up of ERC20/ERC721/ERC1155 and native-token assets
 *           in a data structure, and provides logic for setting/getting IDs and URIs for created crates.
 *  @dev     See {ICrateBundle}
 */

abstract contract CrateBundle is ICrateBundle {
	/// @dev Mapping from crate UID => crate info.
	mapping(uint256 => BundleInfo) private crate;

	/// @dev Returns the total number of assets in a particular crate.
	function getTokenCountOfBundle(uint256 _crateId) public view returns (uint256) {
		return crate[_crateId].count;
	}

	/// @dev Returns an asset contained in a particular crate, at a particular index.
	function getTokenOfBundle(uint256 _crateId, uint256 index) public view returns (Token memory) {
		return crate[_crateId].tokens[index];
	}

	function getCrateTypeOfBundle(uint256 _crateId) public view returns (CrateType) {
		require(
			crate[_crateId].crateType == CrateType.RARITY_CRATE,
			"FCCr: !NERC"
		);

		return crate[_crateId].crateType;
	}

	function getRarityOfToken(uint256 _crateId, uint256 _index) public view returns (Rarity) {
		require(
			crate[_crateId].crateType == CrateType.RARITY_CRATE,
			"FCCr: !NERC"
		);

		return crate[_crateId].tokens[_index].rarity;
	}

	function getProbabilityOfCrate(uint256 _crateId) public view returns (uint256[][] memory) {
		return crate[_crateId].probabilities;
	}

	/// @dev Returns the uri of a particular crate.
	function _uriOfBundle(uint256 _crateId) internal view returns (string memory) {
		return crate[_crateId].uri;
	}

	function _calculateRarities(uint256 crateId)
		internal
		view
		returns (uint256[] memory rarityOfCratePacked)
	{
		uint256[] memory rarityWrapper = new uint256[](5);
		uint256 totalItems = crate[crateId].count;
		for (uint256 i = 0; i < totalItems; i += 1) {
			Rarity rarity = crate[crateId].tokens[i].rarity;
			uint256 rarityPosition = uint256(rarity) < 1 ? 0 : uint256(rarity) - 1;
 
			rarityWrapper[rarityPosition] += 1;
		}

		return (rarityWrapper);
	}

	function _filterRaritiesAndClassifiedIt(
		uint256 _crateId,
		uint256[] memory disembledRarities,
		uint256 _totalItems
	)
		internal
		view
		returns (
			Token[][] memory itemData
		)
	{
		// TODO: Refactor this mastodontican code
		uint256 rarityLenght = 5;
		Token[][] memory items = new Token[][](rarityLenght);
		items[0] = new Token[](disembledRarities[0]);
		items[1] = new Token[](disembledRarities[1]);
		items[2] = new Token[](disembledRarities[2]);
		items[3] = new Token[](disembledRarities[3]);
		items[4] = new Token[](disembledRarities[4]);
		uint256[] memory arrCountWrapper = new uint256[](rarityLenght);

		for (uint256 i; i < _totalItems; i++) {
			Token memory item = crate[_crateId].tokens[i];
			Rarity rarity = item.rarity;
			uint256 rarityPosition = uint256(rarity) < 1 ? 0 : uint256(rarity) - 1;

			items[rarityPosition][arrCountWrapper[rarityPosition]] = item;
			arrCountWrapper[rarityPosition] += 1;
		}

		return items;
	}

	function _pickRarityByProbability(
		uint256 crateId,
		uint256 randomNumber,
		uint256 probabilityIndex
	) internal view virtual returns (Rarity) {
		uint256 commonRange = crate[crateId].probabilities[probabilityIndex][0];
		uint256 uncommonRange = commonRange + crate[crateId].probabilities[probabilityIndex][1];
		uint256 rareRange = uncommonRange + crate[crateId].probabilities[probabilityIndex][2];
		uint256 epicRange = rareRange + crate[crateId].probabilities[probabilityIndex][3];

		Rarity rarity;

		if (randomNumber <= commonRange) {
			rarity = Rarity.COMMON;
		} else if (randomNumber > commonRange && randomNumber < uncommonRange) {
			rarity = Rarity.UNCOMMON;
		} else if (randomNumber > uncommonRange && randomNumber < rareRange) {
			rarity = Rarity.RARE;
		} else if (randomNumber > rareRange && randomNumber < epicRange) {
			rarity = Rarity.EPIC;
		} else {
			rarity = Rarity.LEGENDARY;
		}

		return rarity;
	}

	/// @dev Lets the calling contract create a crate, by passing in a list of tokens and a unique id.
	function _createBundle(
		Token[] calldata _tokensToBind,
		uint256 _crateId,
		uint256[][] memory _probabilities,
		CrateType _crateType
	) internal {
		uint256 targetCount = _tokensToBind.length;

		require(targetCount > 0, "!Tok");
		require(crate[_crateId].count == 0, "!IDe");

		for (uint256 i; i < targetCount; i++) {
			_checkTokenType(_tokensToBind[i]);
			crate[_crateId].tokens[i] = _tokensToBind[i];
		}

		_saveProbabilitiesAtCreation(_crateId, _probabilities);

		crate[_crateId].crateType = _crateType;
		crate[_crateId].count = targetCount;
	}

	/// @dev Save the probabilities at creation in the BundleInfo Struct
	function _saveProbabilitiesAtCreation(uint256 _crateId, uint256[][] memory _probabilities)
		internal
	{
		if (_probabilities[0].length > 0) {
			crate[_crateId].probabilities = _probabilities;
		}
	}

	/// @dev Lets the calling contract update a crate, by passing in a list of tokens and a unique id.
	function _updateBundle(Token[] memory _tokensToBind, uint256 _crateId) internal {
		require(_tokensToBind.length > 0, "!Tok");

		uint256 currentCount = crate[_crateId].count;
		uint256 targetCount = _tokensToBind.length;
		uint256 check = currentCount > targetCount ? currentCount : targetCount;

		for (uint256 i; i < check; i++) {
			if (i < targetCount) {
				_checkTokenType(_tokensToBind[i]);
				crate[_crateId].tokens[i] = _tokensToBind[i];
			} else if (i < currentCount) {
				delete crate[_crateId].tokens[i];
			}
		}

		crate[_crateId].count = targetCount;
	}

	/// @dev Lets the calling contract add a token to a crate for a unique crate id and index.
	function _addTokenInBundle(Token memory _tokenToBind, uint256 _crateId) internal {
		_checkTokenType(_tokenToBind);
		uint256 id = crate[_crateId].count;

		crate[_crateId].tokens[id] = _tokenToBind;
		crate[_crateId].count += 1;
	}

	/// @dev Lets the calling contract update a token in a crate for a unique crate id and index.
	function _updateTokenInBundle(
		Token memory _tokenToBind,
		uint256 _crateId,
		uint256 _index
	) internal {
		require(_index < crate[_crateId].count, "IDne");
		_checkTokenType(_tokenToBind);
		crate[_crateId].tokens[_index] = _tokenToBind;
	}

	/// @dev Checks if the type of asset-contract is same as the TokenType specified.
	function _checkTokenType(Token memory _token) internal view {
		if (_token.tokenType == TokenType.ERC721) {
			try IERC165(_token.assetContract).supportsInterface(0x80ac58cd) returns (
				bool supported721
			) {
				require(supported721, "!TokT");
			} catch {
				revert("!TokT");
			}
		} else if (_token.tokenType == TokenType.ERC1155) {
			try IERC165(_token.assetContract).supportsInterface(0xd9b67a26) returns (
				bool supported1155
			) {
				require(supported1155, "!TokT");
			} catch {
				revert("!TokT");
			}
		} else if (_token.tokenType == TokenType.ERC20) {
			if (_token.assetContract != CurrencyTransferLib.NATIVE_TOKEN) {
				// 0x36372b07
				try IERC165(_token.assetContract).supportsInterface(0x80ac58cd) returns (
					bool supported721
				) {
					require(!supported721, "!TokT");

					try IERC165(_token.assetContract).supportsInterface(0xd9b67a26) returns (
						bool supported1155
					) {
						require(!supported1155, "!TokT");
					} catch Error(string memory) {} catch {}
				} catch Error(string memory) {} catch {}
			}
		}
	}

	/// @dev Lets the calling contract set/update the uri of a particular crate.
	function _setUriOfBundle(string memory _uri, uint256 _crateId) internal {
		crate[_crateId].uri = _uri;
	}

	/// @dev Lets the calling contract delete a particular crate.
	function _deleteBundle(uint256 _crateId) internal {
		for (uint256 i; i < crate[_crateId].count; i++) {
			delete crate[_crateId].tokens[i];
		}
		crate[_crateId].count = 0;

	}
}