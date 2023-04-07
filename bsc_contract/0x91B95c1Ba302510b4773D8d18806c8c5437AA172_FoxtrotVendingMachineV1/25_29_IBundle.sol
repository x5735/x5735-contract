// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

/**
 *  Group together arbitrary ERC20, ERC721 and ERC1155 tokens into a single bundle.
 *
 *  The `Token` struct is a generic type that can describe any ERC20, ERC721 or ERC1155 token.
 *  The `Bundle` struct is a data structure to track a group/bundle of multiple assets i.e. ERC20,
 *  ERC721 and ERC1155 tokens, each described as a `Token`.
 *
 *  Expressing tokens as the `Token` type, and grouping them as a `Bundle` allows for writing generic
 *  logic to handle any ERC20, ERC721 or ERC1155 tokens.
 */

interface IBundle {
	/**
	 * @title Enumeration of token types
	 * @dev Enumeration of token types, which can be ERC20, ERC721 and ERC1155.
	 */
	enum TokenType {
		ERC20,
		ERC721,
		ERC1155
	}

	/**
	 * @title Payment structure
	 * @dev This struct contains information about a payment, 
     *      including token type, asset contract address and amount.
	 */
	struct Payment {
		TokenType tokenType;
		address assetContract;
		uint256 tokenId;
		uint256 requiredAmount;
	}

	/**
	 * @title Product structure
	 * @dev This struct contains information about a product, 
     *      including token type, asset contract address, token Id, 
     *      total quantity and amount to drop on payment.
	 */
	struct Product {
		TokenType tokenType;
		uint256 tokenId;
		address assetContract;
		uint256 currentSupply;
		uint256 totalSupply;
		uint256 amountToDispenseOnPayment;
	}

	/**
	 * @title Encapsulated Products Structure
	 * @dev This struct contains information about a set of 
     *      products, including count, URI and products mapping.
	 */
	struct EncapsulatedProducts {
		string uri;
		uint256 productsCount;
		uint256 paymentsCount;
		bool singlePayment;
		mapping(uint256 => Product) products;
		mapping(uint256 => Payment) payments;
	}
}