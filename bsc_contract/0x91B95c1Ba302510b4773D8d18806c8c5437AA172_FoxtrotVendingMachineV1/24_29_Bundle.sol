// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "contracts/base/IBundle.sol";
import "contracts/lib/CurrencyTransferLib.sol";

interface IERC165 {
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract Bundle is IBundle {
	/**
	 * @dev Mapping from crate UID to crate information.
	 */
	mapping(uint256 => EncapsulatedProducts) private capsule;

	/**
	 * @dev Returns the total number of products in a specific crate.
	 * @param _capsuleId Unique identifier of the crate.
	 * @return The total number of products in the crate.
	 */
	function getProductCountOfBundle(uint256 _capsuleId) public view returns (uint256) {
		return capsule[_capsuleId].productsCount;
	}

	/**
	 * @dev Returns the total number of payment methods in a specific crate.
	 * @param _capsuleId Unique identifier of the crate.
	 * @return The total number of payment methods in the crate.
	 */
	function getPaymentCountOfBundle(uint256 _capsuleId) public view returns (uint256) {
		return capsule[_capsuleId].paymentsCount;
	}

	/**
	 * @dev Returns the total number of payment methods in a specific crate.
	 * @param _capsuleId Unique identifier of the crate.
	 * @return The total number of payment methods in the crate.
	 */
	function hasSinglePayment(uint256 _capsuleId) public view returns (bool) {
		return capsule[_capsuleId].singlePayment;
	}

	/**
	 * @dev Returns a product contained in a specific crate, at a specific index.
	 * @param _capsuleId Unique identifier of the crate.
	 * @param index The index of the product within the crate.
	 * @return The product at the specified index.
	 */
	function getProductOfBundle(uint256 _capsuleId, uint256 index)
		public
		view
		returns (Product memory)
	{
		return capsule[_capsuleId].products[index];
	}

	/**
	 * @dev Returns a payment method contained in a specific crate, at a specific index.
	 * @param _capsuleId Unique identifier of the crate.
	 * @param index The index of the payment method within the crate.
	 * @return The payment method at the specified index.
	 */
	function getPaymentOfBundle(uint256 _capsuleId, uint256 index)
		public
		view
		returns (Payment memory)
	{
		return capsule[_capsuleId].payments[index];
	}

	/**
	 * @dev Returns the URI (Uniform Resource Identifier) of a particular bundle.
	 * @param _capsuleId ID of the capsule
	 * @return uri of the bundle
	 */
	function getUriOfBundle(uint256 _capsuleId) public view returns (string memory) {
		return capsule[_capsuleId].uri;
	}

	/**
	 * @dev Returns the current supply of a product in a particular bundle.
	 * @param _capsuleId ID of the capsule
	 * @param index Index of the product
	 * @return Current supply of the product
	 */
	function getCurrentSupplyOfProduct(uint256 _capsuleId, uint256 index)
		public
		view
		returns (uint256)
	{
		return capsule[_capsuleId].products[index].currentSupply;
	}

	/**
	 * @dev Decreases the supply of a product in a bundle.
	 * @param _capsuleId ID of the capsule
	 * @param _index Index of the product
	 * @param _amountToDecrease Amount to decrease the supply
	 */
	function _decreaseSupplyOfProduct(
		uint256 _capsuleId,
		uint256 _index,
		uint256 _amountToDecrease
	) internal {
		uint256 currentSupply = capsule[_capsuleId].products[_index].currentSupply;

		require(currentSupply >= _amountToDecrease, "FCVM: !InvalidAmountOfSupply");
		capsule[_capsuleId].products[_index].currentSupply -= _amountToDecrease;
	}

	/**
	 * @dev Creates a bundle of products and payments.
	 * @param _productsToBind Array of products to be bound in the bundle
	 * @param _paymentsToBind Array of payments to be bound in the bundle
	 * @param _capsuleId ID of the capsule
	 */
	function _createBundle(
		Product[] calldata _productsToBind,
		Payment[] calldata _paymentsToBind,
		bool singlePayment,
		uint256 _capsuleId
	) internal {
		uint256 productLength = _productsToBind.length;
		uint256 paymentLength = _paymentsToBind.length;

		require(productLength != 0, "FCVM: !InvAmntProd");
		require(
			capsule[_capsuleId].productsCount + capsule[_capsuleId].paymentsCount == 0,
			"FCVM: CapsuleIdExist"
		);

		for (uint256 i; i < productLength; ++i) {
			_checkTokenType(_productsToBind[i]);
			capsule[_capsuleId].products[i] = _productsToBind[i];
		}

		for (uint256 i = 0; i < paymentLength; i += 1) {
			capsule[_capsuleId].payments[i] = _paymentsToBind[i];
		}

		capsule[_capsuleId].singlePayment = singlePayment;
		capsule[_capsuleId].productsCount = productLength;
		capsule[_capsuleId].paymentsCount = paymentLength;
	}

	/**
	 * @dev Add token to the product bundle
	 * @param _productToBind The token to add to the bundle
	 * @param _capsuleId The id of the product to update
	 */
	function _addProductToBundle(Product memory _productToBind, uint256 _capsuleId) internal {
		_checkTokenType(_productToBind);
		uint256 productId = capsule[_capsuleId].productsCount;

		capsule[_capsuleId].products[productId] = _productToBind;
		capsule[_capsuleId].productsCount += 1;
	}

	/**
	 * @dev Update a token in the product bundle
	 * @param _productToBind The updated token
	 * @param _capsuleId The id of the product to update
	 * @param _index The index of the token in the bundle to update
	 */
	function _updateTokenInBundle(
		Product memory _productToBind,
		uint256 _capsuleId,
		uint256 _index
	) internal {
		require(_index < capsule[_capsuleId].productsCount, "index DNE");
		_checkTokenType(_productToBind);
		capsule[_capsuleId].products[_index] = _productToBind;
	}

	/**
	 * @dev Check if the provided product is of a valid TokenType
	 * @param _product The product to check
	 */
	function _checkTokenType(Product memory _product) internal view {
		if (_product.tokenType == TokenType.ERC721) {
			try IERC165(_product.assetContract).supportsInterface(0x80ac58cd) returns (
				bool supported721
			) {
				require(supported721, "!TokenType");
			} catch {
				revert("!TokenType");
			}
		} else if (_product.tokenType == TokenType.ERC1155) {
			try IERC165(_product.assetContract).supportsInterface(0xd9b67a26) returns (
				bool supported1155
			) {
				require(supported1155, "!TokenType");
			} catch {
				revert("!TokenType");
			}
		} else if (_product.tokenType == TokenType.ERC20) {
			if (_product.assetContract != CurrencyTransferLib.NATIVE_TOKEN) {
				// 0x36372b07
				try IERC165(_product.assetContract).supportsInterface(0x80ac58cd) returns (
					bool supported721
				) {
					require(!supported721, "!TokenType");

					try IERC165(_product.assetContract).supportsInterface(0xd9b67a26) returns (
						bool supported1155
					) {
						require(!supported1155, "!TokenType");
					} catch Error(string memory) {} catch {}
				} catch Error(string memory) {} catch {}
			}
		}
	}

	/**
	 * @dev Function to set the URI of a bundle.
	 * @param _uri URI of the bundle
	 * @param _capsuleId Id of the capsule to set the URI for.
	 */
	function _setUriOfBundle(string memory _uri, uint256 _capsuleId) internal {
		capsule[_capsuleId].uri = _uri;
	}

	/**
	 * @dev Function to get the URI of a bundle.
	 * @param _capsuleId Id of the capsule to get the URI for.
	 * @return URI of the bundle
	 */
	function _getUriOfBundle(uint256 _capsuleId) internal view returns (string memory) {
		return capsule[_capsuleId].uri;
	}

	/**
	 * @dev Function to delete a bundle.
	 * @param _capsuleId Id of the capsule to be deleted.
	 */
	function _deleteBundle(uint256 _capsuleId) internal {
		for (uint256 i; i < capsule[_capsuleId].paymentsCount; ++i) {
			delete capsule[_capsuleId].payments[i];
		}
		capsule[_capsuleId].paymentsCount = 0;

		for (uint256 i; i < capsule[_capsuleId].productsCount; ++i) {
			delete capsule[_capsuleId].products[i];
		}
		capsule[_capsuleId].productsCount = 0;
	}
}