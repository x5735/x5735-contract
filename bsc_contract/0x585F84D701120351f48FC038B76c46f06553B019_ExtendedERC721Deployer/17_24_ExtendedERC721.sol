pragma solidity 0.8.17;

import "./CustomERC721.sol";
import "./PreSale721.sol";
import "./I_NFT.sol";

contract ExtendedERC721 is PreSale721, CustomERC721{

    mapping(uint256 => string) private customUri;

    /*
     * Params
     * address owner_ - Address that will become contract owner
     * address dercyptMarketplaceAddress_ - Decrypt Marketplace proxy address
     * string memory name_ - Token name
     * string memory symbol_ - Token Symbol
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royaly in basis points (1000 = 10%)
     * address preSalePaymentToken_ - ERC20 token address, that will be used for pre sale payment
     *                                address (0) for ETH
     */
    constructor(
        address owner_,
        address dercyptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    )
        CustomERC721(
            owner_,
            dercyptMarketplaceAddress_,
            name_,
            symbol_,
            uri_,
            royalty_
        )
    {
        preSalePaymentToken = preSalePaymentToken_;
    }


    /*
     * Params
     * uint256 eventId - Event ID index
     * address buyer - User address, who bought the tokens
     *
     * Function counts tokens bought for different Pre-Sale counters
     */
    function countTokensBought(
        uint256 eventId,
        address buyer
    ) external onlyDecrypt{
        _countTokensBought(eventId, buyer);
    }


    /*
     * Params
     * uint256 tokenId - ID index of the token
     *
     * Function returns token URI.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if(bytes(customUri[tokenId]).length != 0){
            return customUri[tokenId];
        }
        return super.tokenURI(tokenId);
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(CustomERC721) returns (bool) {
        return
        interfaceId == type(IPreSale721).interfaceId ||
        super.supportsInterface(interfaceId);
    }

}