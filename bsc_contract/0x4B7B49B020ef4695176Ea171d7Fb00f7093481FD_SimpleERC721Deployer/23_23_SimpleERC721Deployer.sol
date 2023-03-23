pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

import './DeployersInterfaces.sol';
import './SimpleERC721.sol';

contract SimpleERC721Deployer is AccessControl, ISimpleERC721Deployer{

    address public creator;
    bytes32 internal constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 internal constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    event CreatorSet(address);

    /*
     * Params
     * address _NFTcreator - address of proxy - NFT-Creator, that will send request for contracts deployment
     */
    constructor(
        address _NFTcreator
    ){
        creator = _NFTcreator;
        _setupRole(CREATOR_ROLE, _NFTcreator);
        _setupRole(OWNER_ROLE, msg.sender);
    }


    /*
     * Params
     * address owner_ - Address that will become contract owner
     * string memory name_ - Token name
     * string memory symbol_ - Token Symbol
     * string memory uri_ - Base token URI
     * uint256 royalty_ - Base royaly in basis points (1000 = 10%)
     *
     * Function deploys token contract and assigns owner
     */
    function deployToken(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_
    )
    external onlyRole(CREATOR_ROLE)
    override
    returns(address)
    {
        return address(new SimpleERC721(
                owner_,
                decryptMarketplaceAddress_,
                name_,
                symbol_,
                uri_,
                royalty_
            ));
    }


    /*
     * Params
     * address _creator - Address of the contract that will be able to deploy NFT contracts
     * Should be proxy-NFT-creator address
     *
     * Function sets role for proxy-NFT-creator that allows to deploy contracts
     */
    function setCreator(address _creator) external onlyRole(OWNER_ROLE){
        require (_creator != address(0), 'Cant accept 0 address');
        creator = _creator;
        grantRole(CREATOR_ROLE, _creator);

        emit CreatorSet(_creator);
    }
}