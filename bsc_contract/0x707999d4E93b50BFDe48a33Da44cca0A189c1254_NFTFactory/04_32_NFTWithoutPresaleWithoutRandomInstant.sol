// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Base/BaseNFTWithoutPresale.sol";

contract NFTWithoutPresaleWithoutRandomInstant is BaseNFTWithoutPresale {
    string public saleType;
    uint256 public version;

    /**
    @notice This is initializer function is used to deploy new sale contract  
    @param _name Collection name  
    @param _symbol Collection symbol  
    @param _saleType sale Type
    @param _baseUri Collection Base URI  
    @param _maxSupply Collection max supply  
    @param _saleId backend sale id   
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address  
    */
    function __NFTWithoutPresaleWithoutRandomInstant_init(
        string memory _name,
        string memory _symbol,
        string memory _saleType,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId,
        publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) public initializer {
        require(_maxSupply > 0, "Init: Invalid max supply");
        require(_publicSaleConfig._publicSaleMintCost > 100, "Init: Invalid Token cost");
        require(block.timestamp <= _publicSaleConfig._publicSaleStartTime, "Init: Invalid Start Time");
        require(_publicSaleConfig._publicSaleDuration > 0, "Init: sale duration > 0");
        require(_publicSaleConfig._maxTokenPerMintPublicSale > 0, "Init: Maximum token per mint in public sale > 0");
        require(
            both(
                _publicSaleConfig._maxTokenPerPersonPublicSale >= _publicSaleConfig._maxTokenPerMintPublicSale,
                _publicSaleConfig._maxTokenPerPersonPublicSale <= _maxSupply
            ),
            "Init: Invalid MaxTokenPerPerson of public sale"
        );

        __ERC1155_init(_baseUri);
        __Ownable_init();

        name = _name;
        symbol = _symbol;
        saleType = _saleType;
        baseUri = _baseUri;
        maxSupply = _maxSupply;
        saleId = _saleId;

        publicSaleMintCost = _publicSaleConfig._publicSaleMintCost;
        publicSaleStartTime = _publicSaleConfig._publicSaleStartTime;
        publicSaleEndTime = publicSaleStartTime + _publicSaleConfig._publicSaleDuration;
        maxTokenPerMintPublicSale = _publicSaleConfig._maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _publicSaleConfig._maxTokenPerPersonPublicSale;
        signerAddress = _signerAddress;
        version = 1;
        factory = msg.sender;
    }

    /**
    @notice This function is used to create Airdrop  
    @dev It can only be called by owner  
    @param list list of addresses  
    @param shares public sale shares in Airdrop 
    */

    function createAirdrop(address[] calldata list, uint256[2] calldata shares) external isApproved onlyOwner {
        _initiateAirdrop(list, shares);
    }

    /**
    @notice This function is used to update version of contract
    @param _version version number
    */
    function setVersion(uint256 _version) external onlyOwner {
        version = _version;
    }
}