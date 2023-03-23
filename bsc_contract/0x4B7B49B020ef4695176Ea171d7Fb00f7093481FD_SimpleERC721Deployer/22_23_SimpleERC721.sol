pragma solidity 0.8.17;

import "./CustomERC721.sol";

contract SimpleERC721 is CustomERC721 {

    /*
     * Params
     * address owner_ - Address that will become contract owner
     * address decryptMarketplaceAddress_ - Decrypt Marketplace proxy address
     * string memory name_ - Token name
     * string memory symbol_ - Token Symbol
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royaly in basis points (1000 = 10%)
     */
    constructor(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_
    )
    CustomERC721(
        owner_,
        decryptMarketplaceAddress_,
        name_,
        symbol_,
        uri_,
        royalty_
    )
    {}

}