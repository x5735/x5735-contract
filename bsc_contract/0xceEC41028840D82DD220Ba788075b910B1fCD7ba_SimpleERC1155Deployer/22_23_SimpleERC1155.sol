pragma solidity 0.8.17;

import "./CustomERC1155.sol";

contract SimpleERC1155 is CustomERC1155 {

    /*
     * Params
     * address owner_ - Address that will become contract owner
     * address decryptMarketplaceAddress_ - Decrypt Marketplace proxy address
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royaly in basis points (1000 = 10%)
     */
    constructor(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory uri_,
        uint256 royalty_
    )
        CustomERC1155(
            owner_,
            decryptMarketplaceAddress_,
            uri_,
            royalty_
        )
    {}

}