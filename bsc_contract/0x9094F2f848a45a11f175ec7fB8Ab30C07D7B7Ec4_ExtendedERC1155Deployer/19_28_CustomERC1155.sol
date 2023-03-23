pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import "./RoyaltyDistribution.sol";
import "./PreSale1155.sol";
import "./I_NFT.sol";
import "./IRoyaltyDistribution.sol";

contract CustomERC1155 is RoyaltyDistribution, ERC1155 {

    event UpdatedURI(
        string _uri
    );

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
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royalty in basis points (1000 = 10%)
     */
    constructor(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory uri_,
        uint256 royalty_
    )
        ERC1155(uri_)
    {
        globalRoyalty = royalty_;
        transferOwnership(owner_);
        royaltyReceiver = owner_;
        decryptMarketplaceAddress = decryptMarketplaceAddress_;
    }



    /*
     * Params
     * string memory uri_ - new base token URI
     *
     * Function sets new base token URI
     */
    function setURI(string memory uri_) external onlyOwner {
        _setURI(uri_);

        emit UpdatedURI(
            uri_
        );
    }


    /*
     * Params
     * address account - Who will be the owner of this token?
     * uint256 id - ID index of the token you want to mint
     * uint256 amount - Amount of tokens to mint
     *
     * Mints specific amount of tokens with specific ID and sets specific address as their owner
     */
    function mint(
        address account,
        uint256 id,
        uint256 amount
    ) external onlyOwner {
        _mint(account, id, amount,'0x');
    }


    /*
     * Params
     * address to - Who will be the owner of these tokens?
     * uint256[] memory ids - List of IDs to mint
     * uint256[] memory amounts - List of corresponding amounts
     *
     * Mints specific amounts of tokens with specific IDs and sets specific address as their owner
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOwner {
        _mintBatch(to, ids, amounts,'0x');
    }


    /*
     * Params
     * address to - Who will be the owner of this token?
     * uint256 tokenId - ID index of the token you want to mint
     * uint256 amount - Quantity of tokens to lazy mint
     *
     * Allows Decrypt marketplace to mint tokens
     */
    function lazyMint(address to, uint256 tokenId, uint256 amount) external onlyDecrypt {
        _mint(to, tokenId, amount,'0x');
    }


    /*
     * Params
     * bytes4 interfaceId - interface ID
     *
     * Called to determine interface support
     * Called by marketplace to determine if contract supports IERC2981, that allows royalty calculation.
     * Also called by marketplace to determine if contract supports lazy mint and royalty distribution.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return
        interfaceId == type(IERC2981).interfaceId ||
        interfaceId == type(ILazyMint1155).interfaceId ||
        interfaceId == type(IRoyaltyDistribution).interfaceId ||
        super.supportsInterface(interfaceId);
    }


    /*
     * Params
     * address operator - Address of operator
     * address from - Address sender
     * address to - Address receiver
     * uint256[] memory ids - Array of token index IDs
     * uint256[] memory amounts - Array of token amounts
     * bytes memory data - Additional data
     *
     * Transfers specific amount from sender to receiver token with specific ID.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
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