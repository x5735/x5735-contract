// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "contracts/base/interfaces/ICrateBundleManager.sol";

interface IERC165 {
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract CrateBundleManager is ICrateBundleManager {
	//@notice An internal data structure to track a group / bundle of multiple assets i.e. `Token`s.
	mapping(uint256 => BundleInfo) private crate;

	//@notice An internal data structure to track the probability of a crate.
	mapping(uint256 => uint256[][]) private probabilitiesContainers;
	uint256 private probabilitiesContainerTrackerId;

	/**
	 * @dev Returns the total number of assets i.e. `Token` in a bundle.
	 * @param _crateId The ID of the crate.
	 */
	function getTokenCountOfBundle(uint256 _crateId) public view returns (uint256) {
		return crate[_crateId].count;
	}

	/**
	 * @dev Returns an asset contained in a particular crate, at a particular index.
	 * @param _crateId The ID of the crate.
	 */
	function getTokenIndexInBundle(
		uint256 _crateId,
		uint256 index
	) public view returns (Token memory) {
		return crate[_crateId].tokens[index];
	}

	/**
	 * @dev Returns the CrateType of the crate
	 * @param _crateId The ID of the crate.
	 * @return The CrateType of the crate.
	 */
	function getCrateTypeOfToken(uint256 _crateId) public view returns (CrateType) {
		require(crate[_crateId].crateType == CrateType.RARITY_CRATE, "FCCr: !NERC");

		return crate[_crateId].crateType;
	}

	/**
	 * @dev It shows the rarities of the tokens in a crate in a specific index
	 * @param _crateId The ID of the crate.
	 * @param _index The index of the token.
	 * @return The rarity of the token.
	 */
	function getRarityOfToken(uint256 _crateId, uint256 _index) public view returns (Rarity) {
		require(crate[_crateId].crateType == CrateType.RARITY_CRATE, "FCCr: !NERC");

		return crate[_crateId].tokens[_index].rarity;
	}

	/**
	 * @dev This method is used to get the probability of a crate.
	 * @param _crateId The ID of the crate.
	 * @return The probability of the crate in a 2D array
	 */
	function getProbabilityOfCrate(uint256 _crateId) public view returns (uint256[][] memory) {
		uint256 probabilityIdOnCrate = crate[_crateId].probabilityId;
		return probabilitiesContainers[probabilityIdOnCrate];
	}

	/**
	 * @param _crateId The ID of the crate.
	 * @return The URI of the crate.
	 */
	function _uriOfCrateBundle(uint256 _crateId) internal view returns (string memory) {
		return crate[_crateId].uri;
	}

	/**
	 * @dev Create a new crate bundle.
	 * @param _tokens The array of tokens to be parsed to the crate.
	 * @param _crateIdentifier The identifier of the crate.
	 * @param _crateType The type of the crate.
	 */
	function _createCrateInstance(
		Token[] calldata _tokens,
		string memory _uriForTokens,
		uint256 _crateIdentifier,
		CrateType _crateType
	) internal {
		_createCrateBundle(_tokens, _crateIdentifier, _crateType);
		_setUriOfCrate(_uriForTokens, _crateIdentifier);
	}

	/**
	 * @dev Creates a crate, by passing in a list of tokens and a unique id.
	 * @param _tokensToBind The list of tokens to bind to the crate.
	 * @param _crateId The id of the crate.
	 * @param _crateType The type of crate.
	 */
	function _createCrateBundle(
		Token[] calldata _tokensToBind,
		uint256 _crateId,
		CrateType _crateType
	) internal {
		uint256 targetCount = _tokensToBind.length;

		require(targetCount > 0, "!Tok");
		require(crate[_crateId].count == 0, "!IDe");

		for (uint256 i; i < targetCount; i++) {
			_checkTokenType(_tokensToBind[i]);
			crate[_crateId].tokens[i] = _tokensToBind[i];
		}

		crate[_crateId].crateType = _crateType;
		crate[_crateId].count = targetCount;
	}

	/**
	 * @dev Calculate the raritie values
	 * @param crateId The id of the crate.
	 */
	function _calculateRarities(
		uint256 crateId
	) internal view returns (uint256[] memory rarityOfCratePacked) {
		uint256[] memory rarityWrapper = new uint256[](5);
		uint256 totalItems = crate[crateId].count;
		for (uint256 i = 0; i < totalItems; i += 1) {
			Rarity rarity = crate[crateId].tokens[i].rarity;
			uint256 rarityPosition = uint256(rarity) < 1 ? 0 : uint256(rarity) - 1;

			rarityWrapper[rarityPosition] += 1;
		}

		return (rarityWrapper);
	}

	/**
	 * @dev Filter the rarities and classified it
	 * @param _crateId The id of the crate.
	 * @param disembledRarities The array of the rarities.
	 * @param _totalItems The total items of the crate.
	 */
	function _filterRaritiesAndClassifiedIt(
		uint256 _crateId,
		uint256[] memory disembledRarities,
		uint256 _totalItems
	) internal view returns (Token[][] memory itemData) {
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

	/**
	 * @dev Pick the raritie based on the probability
	 * @param crateId The id of the crate.
	 * @param randomNumber The random number.
	 * @param probabilityIndex The index of the probability.
	 * @return rarity The rarity of the item.
	 */
	function _pickRarityByProbability(
		uint256 crateId,
		uint256 randomNumber,
		uint256 probabilityIndex
	) internal view virtual returns (Rarity) {
		uint256[][] memory crateProbabilities = probabilitiesContainers[
			crate[crateId].probabilityId
		];

		uint256 commonRange = crateProbabilities[probabilityIndex][0];
		uint256 uncommonRange = commonRange + crateProbabilities[probabilityIndex][1];
		uint256 rareRange = uncommonRange + crateProbabilities[probabilityIndex][2];
		uint256 epicRange = rareRange + crateProbabilities[probabilityIndex][3];

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

	/**
	 * @dev Get the probability container length
	 * @param _probId The id of the probability container.
	 * @return The length of the probability container.
	 */
	function _getProbabilityContainerLength(uint256 _probId) internal view returns (uint256) {
		return probabilitiesContainers[_probId].length;
	}

	/**
	 * @dev Lets the calling contract attach probabilities to a crate,
	 * 		by passing in a list of probabilities and a unique id.
	 * @dev The probabilities are passed in as a 2D array
	 * @param _crateId The id of the crate to attach probabilities to.
	 * @param _probContainerId The probabilities to attach to the crate.
	 */
	function _attachProbabilitiesToCrate(uint256 _crateId, uint256 _probContainerId) internal {
		require(probabilitiesContainers[_probContainerId].length != 0, "!Pro");
		crate[_crateId].probabilityId = _probContainerId;
	}

	/**
	 * @dev Create a probability container, by passing in a list of probabilities.
	 * @param _probabilities The probabilities to attach to the crate.
	 * @return probabilitieTracker The id of the probability container.
	 */
	function _createProbabilitieContainer(
		uint256[][] memory _probabilities
	) internal returns (uint256) {
		require(_probabilities[0].length > 0, "!Pro");
		uint256 probabilitieTracker = probabilitiesContainerTrackerId++;
		probabilitiesContainers[probabilitieTracker] = _probabilities;

		return probabilitieTracker;
	}

	/**
	 * @dev Lets the calling contract update a crate, by passing in a list of tokens and a unique id.
	 * @param _tokensToBind The tokens to bind to the crate.
	 * @param _crateId The id of the crate to update.
	 */
	function _updateCrateBundle(Token[] memory _tokensToBind, uint256 _crateId) internal {
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

	/**
	 * @dev Add a token to a crate for a unique crate id.
	 * @param _tokenToBind The token to add to the crate.
	 * @param _crateId The id of the crate to add the token to.
	 */
	function _addTokenToBundle(Token memory _tokenToBind, uint256 _crateId) internal {
		_checkTokenType(_tokenToBind);
		uint256 id = crate[_crateId].count;

		crate[_crateId].tokens[id] = _tokenToBind;
		crate[_crateId].count += 1;
	}

	/**
	 * @dev Update a token in a crate for a unique crate id.
	 * @param _tokenToBind The token to update in the crate.
	 * @param _crateId The id of the crate to update the token in.
	 * @param _index The index of the token to update.
	 */
	function _updateTokenInBundle(
		Token memory _tokenToBind,
		uint256 _crateId,
		uint256 _index
	) internal {
		require(_index < crate[_crateId].count, "IDne");
		_checkTokenType(_tokenToBind);
		crate[_crateId].tokens[_index] = _tokenToBind;
	}

	/**
	 * @dev Set the uri of the
	 * @param _uri The uri to set.
	 * @param _crateId The id of the crate to set the uri of.
	 */
	function _setUriOfCrate(string memory _uri, uint256 _crateId) internal {
		crate[_crateId].uri = _uri;
	}

	/**
	 * @dev Delete a crate for a unique crate id.
	 * @param _crateId The id of the crate to delete.
	 */
	function _deleteCrateBundle(uint256 _crateId) internal {
		for (uint256 i; i < crate[_crateId].count; i++) {
			delete crate[_crateId].tokens[i];
		}
		crate[_crateId].count = 0;
	}

	/**
	 * @dev Checks if the token type is ERC721 or ERC1155.
	 * @param _token The token to check.
	 */
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
		}
	}
}