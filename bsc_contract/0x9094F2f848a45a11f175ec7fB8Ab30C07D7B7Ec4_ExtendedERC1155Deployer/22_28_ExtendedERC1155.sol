pragma solidity 0.8.17;

import "./CustomERC1155.sol";
import "./PreSale1155.sol";
import "./I_NFT.sol";
import "./CustomERC721.sol";

contract ExtendedERC1155 is PreSale1155, CustomERC1155{

    mapping(uint256 => string) private customUri;

    /*
     * Params
     * address owner_ - Address that will become contract owner
     * address decryptMarketplaceAddress_ - Decrypt Marketplace proxy address
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royaly in basis points (1000 = 10%)
     * address preSalePaymentToken_ - ERC20 token address, that will be used for pre sale payment
     *                                address (0) for ETH
     */
    constructor(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    )
        CustomERC1155(
            owner_,
            decryptMarketplaceAddress_,
            uri_,
            royalty_
        )
    {
        preSalePaymentToken = preSalePaymentToken_;
    }


    /*
     * Params
     * uint256 eventId - Event ID index
     * uint256 tokenId - Index ID of token sold
     * uint256 amount - Amount of tokens sold
     * address buyer - User address, who bought the tokens
     *
     * Function counts tokens bought for different Pre-Sale counters
     */
    function countTokensBought(
        address buyer,
        uint256 tokenId,
        uint256 amount,
        uint256 eventId
    ) external onlyDecrypt{
        _countTokensBought(buyer, tokenId, amount, eventId);
    }


    /*
     * Params
     * uint256 tokenId - ID index of the token
     *
     * Function returns token URI.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        if(bytes(customUri[tokenId]).length != 0){
            return customUri[tokenId];
        }
        return super.uri(tokenId);
    }


    /*
     * Params
     * uint256 tokenId - Token index ID
     * string memory _customUri - New URI for this token
     *
     * Function sets custom URI address for specific token
     */
    function setCustomTokenUri(uint256 tokenId, string memory _customUri) external onlyOwner {
        customUri[tokenId] = _customUri;
    }


    /*
     * Params
     * bytes4 interfaceId - interface ID
     *
     * Called to determine interface support
     * Called by marketplace to determine if contract supports IPreSale721, that allows Pre-Sale.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(CustomERC1155) returns (bool) {
        return
        interfaceId == type(IPreSale1155).interfaceId ||
        super.supportsInterface(interfaceId);
    }

}