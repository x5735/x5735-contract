// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import { Bundle, IBundle } from "contracts/base/Bundle.sol";
import "contracts/lib/CurrencyTransferLib.sol";

contract TokenStore is
	Bundle,
	ERC721Holder,
	ERC1155Holder
{
	address private chainNativeWrapper;

	constructor(address nativeTokenWrapper) {
		chainNativeWrapper = nativeTokenWrapper;
	}

	/**
	 * @dev Returns the URI for a specific token.
	 * @param _tokenId The token ID.
	 * @return string URI for the token.
	 */
	function _getUri(uint256 _tokenId) internal view returns (string memory) {
		return _getUriOfBundle(_tokenId);
	}

	/**
	 * @param _tokenOwner The owner of the tokens.
	 * @param _products The products to be stored.
	 * @param _payments The payment methods to be stored.
	 * @param singlePayment If the payment methods are separated.
	 * @param _uriForTokens The URI for the tokens.
	 * @param _capsuleId The ID of the capsule.
	 */
	function _storeItems(
		address _tokenOwner,
		Product[] calldata _products,
		Payment[] calldata _payments,
		bool singlePayment,
		string memory _uriForTokens,
		uint256 _capsuleId
	) internal {
		_createBundle(_products, _payments, singlePayment, _capsuleId);
		_setUriOfBundle(_uriForTokens, _capsuleId);

		uint256 count = getProductCountOfBundle(_capsuleId);
		Product[] memory itemsToStore = new Product[](count);
		for (uint256 i = 0; i < count; i += 1) {
			Product memory product = getProductOfBundle(_capsuleId, i);
			itemsToStore[i] = Product({
				assetContract: product.assetContract,
				tokenType: product.tokenType,
				tokenId: product.tokenId,
				totalSupply: product.totalSupply,
				currentSupply: product.currentSupply,
				// This change is only necessary on the first Store Items.
				amountToDispenseOnPayment: product.totalSupply
			});
		}

		_transferTokenBatch(_tokenOwner, address(this), itemsToStore);
	}

	/**
	 * @dev Dispense stored / escrowed ERC1155, ERC721, ERC20 tokens.
	 * @param _capsuleId The capsule id.
	 * @param _recipient The recipient address.
	 */
	function _dispenseItems(uint256 _capsuleId, uint256 _amount, address _recipient) internal {
		uint256 count = getProductCountOfBundle(_capsuleId);

		Product[] memory itemsToDispense = new Product[](count);
		for (uint256 i = 0; i < count; i += 1) {
			Product memory product = getProductOfBundle(_capsuleId, i);

			require(product.amountToDispenseOnPayment * _amount <= product.currentSupply, "FCVM: Insufficient supply");

			itemsToDispense[i] = Product({
				assetContract: product.assetContract,
				tokenType: product.tokenType,
				tokenId: product.tokenId,
				totalSupply: product.totalSupply,
				currentSupply: product.currentSupply,
				amountToDispenseOnPayment: product.amountToDispenseOnPayment * _amount
			});

			_decreaseSupplyOfProduct(_capsuleId, i, product.amountToDispenseOnPayment * _amount);
		}

		_transferTokenBatch(address(this), _recipient, itemsToDispense);
	}

	/// @dev Release stored / escrowed ERC1155, ERC721, ERC20 tokens.
	function _releaseTokens(address _recipient, uint256 _capsuleId)
		internal
	{
		uint256 count = getProductCountOfBundle(_capsuleId);
		Product[] memory tokensToRelease = new Product[](count);

		for (uint256 i = 0; i < count; i += 1) {
			tokensToRelease[i] = getProductOfBundle(_capsuleId, i);
		}

		_deleteBundle(_capsuleId);

		_transferTokenBatch(address(this), _recipient, tokensToRelease);
	}

	/**
	 * @dev Transfer token batch
	 * @param _account The address to check balance
	 * @param _payment The payment method to scrow
	 * @return balance The balance of the account
	 */
	function _balanceOf(
		address _account,
		Payment memory _payment
	) internal view returns(uint256 balance){
		if (_payment.tokenType == TokenType.ERC20) {
			balance = IERC20(_payment.assetContract).balanceOf(_account);
		} else if (_payment.tokenType == TokenType.ERC721) {
			balance = IERC721(_payment.assetContract).balanceOf(_account);
		} else if (_payment.tokenType == TokenType.ERC1155) {
			balance = IERC1155(_payment.assetContract).balanceOf(_account, _payment.tokenId);
		}
	}

	/**
	 * @dev Pay product in the selected currency or currencies
	 * @param _from The address to transfer from
	 * @param _to The address to transfer to
	 * @param _payment The payment attributes
	 */
	function _payProduct(
		address _from,
		address _to,
		Payment memory _payment
	) internal {
		if (_payment.tokenType == TokenType.ERC20) {
			CurrencyTransferLib.transferCurrencyWithWrapper(
				_payment.assetContract,
				_from,
				_to,
				_payment.requiredAmount,
				chainNativeWrapper
			);
		} else if (_payment.tokenType == TokenType.ERC721) {
			IERC721(_payment.assetContract).safeTransferFrom(_from, _to, _payment.tokenId);
		} else if (_payment.tokenType == TokenType.ERC1155) {
			IERC1155(_payment.assetContract).safeTransferFrom(_from, _to, _payment.tokenId, _payment.requiredAmount, "");
		}
	}

	/// @dev Transfers an arbitrary ERC20 / ERC721 / ERC1155 token.
	function _transferToken(
		address _from,
		address _to,
		Product memory _token
	) internal {
		if (_token.tokenType == TokenType.ERC20) {
			CurrencyTransferLib.transferCurrencyWithWrapper(
				_token.assetContract,
				_from,
				_to,
				_token.amountToDispenseOnPayment,
				chainNativeWrapper
			);
		} else if (_token.tokenType == TokenType.ERC721) {
			IERC721(_token.assetContract).safeTransferFrom(
				_from,
				_to,
				_token.tokenId
			);
		} else if (_token.tokenType == TokenType.ERC1155) {
			IERC1155(_token.assetContract).safeTransferFrom(
				_from,
				_to,
				_token.tokenId,
				_token.amountToDispenseOnPayment,
				""
			);
		}
	}

	/// @dev Transfers multiple arbitrary ERC20 / ERC721 / ERC1155 tokens.
	function _transferTokenBatch(
		address _from,
		address _to,
		Product[] memory _products
	) internal {
		uint256 nativeTokenValue;
		for (uint256 i = 0; i < _products.length; i += 1) {
			if (
				_products[i].assetContract == CurrencyTransferLib.NATIVE_TOKEN &&
				_to == address(this)
			) {
				nativeTokenValue += _products[i].totalSupply;
			} else {
				_transferToken(_from, _to, _products[i]);
			}
		}
		if (nativeTokenValue != 0) {
			Product memory _nativeToken = Product({
				assetContract: CurrencyTransferLib.NATIVE_TOKEN,
				tokenType: IBundle.TokenType.ERC20,
				tokenId: 0,
				totalSupply: nativeTokenValue,
				currentSupply: nativeTokenValue,
				amountToDispenseOnPayment: nativeTokenValue
			});
			_transferToken(_from, _to, _nativeToken);
		}
	}
}