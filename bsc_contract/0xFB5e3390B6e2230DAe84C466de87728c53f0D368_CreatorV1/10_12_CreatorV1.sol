pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import './DeployersInterfaces.sol';
import './I_NFT.sol';

contract CreatorV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    event ERC721Deployed(
        address owner,
        string name,
        string symbol,
        string uri,
        uint256 royalty,
        address tokenAddress
    );

    event ERC1155Deployed(
        address owner,
        string uri,
        uint256 royalty,
        address tokenAddress
    );

    address public decryptMarketplaceAddress;
    mapping(address => bool) public deployedTokenContract;

    ISimpleERC721Deployer simpleERC721Deployer;
    IExtendedERC721Deployer extendedERC721Deployer;
    ISimpleERC1155Deployer simpleERC1155Deployer;
    IExtendedERC1155Deployer extendedERC1155Deployer;


    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }


    /*
     * Params
     * string memory name_ - NFT name
     * string memory symbol_ - NFT symbol
     * string memory uri_ - Base URI of NFT metadata
     * uint256 royalty_ - default base royalty in basis points  that owner will receive (1000 = 10%)
     *
     * Deploys simple ERC721 contract, that supports base functions and flexible royalty management
     */
    function deploySimpleERC721(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_
    )
    external
    returns (address)
    {
        address tokenAddress =  simpleERC721Deployer.deployToken(
            msg.sender,
            decryptMarketplaceAddress,
            name_,
            symbol_,
            uri_,
            royalty_
        );
        deployedTokenContract[tokenAddress] = true;

        emit ERC721Deployed(
            msg.sender,
            name_,
            symbol_,
            uri_,
            royalty_,
            tokenAddress
        );

        return tokenAddress;
    }


    /*
     * Params
     * string memory name_ - NFT name
     * string memory symbol_ - NFT symbol
     * string memory uri_ - Base URI of NFT metadata
     * uint256 royalty_ - default base royalty in basis points  that owner will receive (1000 = 10%)
     * address preSalePaymentToken_ - ERC20 token address, that will be used for pre sale payment
     *                                address (0) for ETH
     *
     * Deploys extended ERC721 contract, that supports base functions, flexible royalty management
     * Pre-Sale functionality and custom token URI
     */
    function deployExtendedERC721(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    )
    external
    returns (address)
    {
        address tokenAddress = extendedERC721Deployer.deployToken(
            msg.sender, 
            decryptMarketplaceAddress,
            name_,
            symbol_,
            uri_,
            royalty_,
            preSalePaymentToken_
        );
        deployedTokenContract[tokenAddress] = true;

        emit ERC721Deployed(
            msg.sender,
            name_,
            symbol_,
            uri_,
            royalty_,
            tokenAddress
        );

        return tokenAddress;
    }


    /*
     * Params
     * string memory uri_ - URI of NFT metadata. Any {id} string will be replaced with token ID on the client side
     * uint256 royalty_ - default base royalty in basis points  that owner will receive (1000 = 10%)
     *
     * Deploys simple ERC1155 contract, that supports base functions and flexible royalty management
     */
    function deploySimpleERC1155(
        string memory uri_,
        uint256 royalty_
    )
    external
    returns (address)
    {
        address tokenAddress =  simpleERC1155Deployer.deployToken(
            msg.sender,
            decryptMarketplaceAddress,
            uri_,
            royalty_
        );
        deployedTokenContract[tokenAddress] = true;

        emit ERC1155Deployed(
            msg.sender,
            uri_,
            royalty_,
            tokenAddress
        );

        return tokenAddress;
    }


    /*
     * Params
     * string memory uri_ - Base URI of NFT metadata
     * uint256 royalty_ - default base royalty in basis points  that owner will receive (1000 = 10%)
     * address preSalePaymentToken_ - ERC20 token address, that wi9ll be used for pre sale payment
     *                                address (0) for ETH
     *
     * Deploys extended ERC1155 contract, that supports base functions, flexible royalty management
     * Pre-Sale functionality and custom token URI
     */
    function deployExtendedERC1155(
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    )
    external
    returns (address)
    {
        address tokenAddress = extendedERC1155Deployer.deployToken(
            msg.sender,
            decryptMarketplaceAddress,
            uri_,
            royalty_,
            preSalePaymentToken_
        );
        deployedTokenContract[tokenAddress] = true;

        emit ERC1155Deployed(
            msg.sender,
            uri_,
            royalty_,
            tokenAddress
        );

        return tokenAddress;
    }


    /*
     * Params
     * ISimpleERC721Deployer _simpleERC721Deployer - Address of Simple ERC721 Deployer
     * IExtendedERC721Deployer _extendedERC721Deployer - Address of Extended ERC721 Deployer
     * ISimpleERC1155Deployer _simpleERC1155Deployer - Address of Simple ERC1155 Deployer
     * IExtendedERC1155Deployer _extendedERC1155Deployer - Address of Extended ERC1155 Deployer
     *
     * Sets marketplace address and list of deployer contracts to work with
     */
    function setMarketplaceAndDeployers(
        address decryptMarketplaceAddress_,
        ISimpleERC721Deployer _simpleERC721Deployer,
        IExtendedERC721Deployer _extendedERC721Deployer,
        ISimpleERC1155Deployer _simpleERC1155Deployer,
        IExtendedERC1155Deployer _extendedERC1155Deployer
        )
    external
    onlyOwner
    {
        decryptMarketplaceAddress = decryptMarketplaceAddress_;
        simpleERC721Deployer = _simpleERC721Deployer;
        extendedERC721Deployer = _extendedERC721Deployer;
        simpleERC1155Deployer = _simpleERC1155Deployer;
        extendedERC1155Deployer = _extendedERC1155Deployer;
    }


    /*
     * Params
     * address newImplementation - Address of the contract with new implementation
     *
     * This function is called before proxy upgrade and makes sure it is authorized.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}


    /*
     * Function returns address of current implementation
     */
    function implementationAddress() external view returns (address){
        return _getImplementation();
    }

}