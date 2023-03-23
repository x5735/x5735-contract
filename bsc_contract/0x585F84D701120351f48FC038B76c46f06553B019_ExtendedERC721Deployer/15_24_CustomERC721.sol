pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

import "./RoyaltyDistribution.sol";
import "./PreSale1155.sol";
import "./I_NFT.sol";
import "./IRoyaltyDistribution.sol";

abstract contract CustomERC721 is RoyaltyDistribution, ERC721{
    using Strings for uint256;

    event UpdatedURI(
        string _uri
    );

    string private _uri;

    address public decryptMarketplaceAddress;

    bool private isForbiddenToTradeOnOtherMarketplaces = false;

    modifier onlyDecrypt {
        require(msg.sender == decryptMarketplaceAddress, 'Unauthorized');
        _;
    }


    /*
     * Params
     * address owner_ - Address that will become contract owner
     * address decryptMarketplaceAddress_ - Decrypt Marketplace proxy address
     * string memory name_ - Token name
     * string memory symbol_ - Token Symbol
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royalty in basis points (1000 = 10%)
     */
    constructor(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_
    )
        ERC721(name_, symbol_)
    {
        _uri = uri_;
        globalRoyalty = royalty_;
        transferOwnership(owner_);
        royaltyReceiver = owner_;
        decryptMarketplaceAddress = decryptMarketplaceAddress_;
    }


    /*
     * Returns NTF base token URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }



    /*
     * Returns NTF base token URI. External function
     */
    function baseURI() external view returns (string memory) {
        return _baseURI();
    }


    /*
     * Params
     * string memory uri_ - new base token URI
     *
     * Function sets new base token URI
     */
    function setURI(string memory uri_) external onlyOwner {
        _uri = uri_;

        emit UpdatedURI(
            uri_
        );
    }


    /*
     * Params
     * address to - Who will be the owner of this token?
     * uint256 tokenId - ID index of the token you want to mint
     *
     * Mints token with specific ID and sets specific address as its owner
     */
    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }


    /*
     * Params
     * address to - Who will be the owner of this token?
     * uint256 tokenId - ID index of the token you want to mint
     *
     * Allows Decrypt marketplace to mint tokens
     */
    function lazyMint(address to, uint256 tokenId) external onlyDecrypt {
        _safeMint(to, tokenId);
    }


    /*
     * Params
     * uint256 tokenId - ID index of the token
     *
     * Function checks if token exists
     */
    function exists(uint256 tokenId) public view returns (bool){
        return _exists(tokenId);
    }


    /*
     * Overwritten Openzeppelin function without require of token to exist
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }


    /*
     * Params
     * bytes4 interfaceId - interface ID
     *
     * Called to determine interface support
     * Called by marketplace to determine if contract supports IERC2981, that allows royalty calculation.
     * Also called by marketplace to determine if contract supports lazy mint and royalty distribution.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return
        interfaceId == type(IERC2981).interfaceId ||
        interfaceId == type(ILazyMint721).interfaceId ||
        interfaceId == type(IRoyaltyDistribution).interfaceId ||
        super.supportsInterface(interfaceId);
    }


    /*
     * Params
     * address from - Address sender
     * address to - Address receiver
     * uint256 tokenId - Token index ID
     *
     * Transfers from sender to receiver token with specific ID.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual  {
        bool allowed = !isForbiddenToTradeOnOtherMarketplaces
            || msg.sender == tx.origin ||  msg.sender == decryptMarketplaceAddress;
        require(allowed, "Restricted to Decrypt marketplace only!");
    }


    /*
     * Params
     * bool _forbidden - Do you want to forbid?
     *** true - forbid, false - allow
     *
     * Forbids/allows trading this contract tokens on other marketplaces.
     */
    function forbidToTradeOnOtherMarketplaces(bool _forbidden) external onlyDecrypt {
        require(isForbiddenToTradeOnOtherMarketplaces != _forbidden, "Already set");
        isForbiddenToTradeOnOtherMarketplaces = _forbidden;
    }
}