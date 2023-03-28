// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Base/BaseNFTWithPresale.sol";

contract NFTWithPresaleWithoutRandomInstant is BaseNFTWithPresale {
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
    @param _preSaleConfig Pre Sale configuration data   
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address of presale buyers  
    */
    function __NFTWithPresaleWithoutRandomInstant_init(
        string memory _name,
        string memory _symbol,
        string memory _saleType,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId,
        preSaleConfig memory _preSaleConfig,
        publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) public initializer {
        require(both(_maxSupply > 0, _maxSupply <= 100000), "Init: Invalid max Supply");
        require(
            both(_preSaleConfig._limitSupplyInPreSale > 0, _preSaleConfig._limitSupplyInPreSale <= _maxSupply),
            "Init: Invalid presale supply"
        );
        require(
            both(_preSaleConfig._preSaleMintCost >= 100, _publicSaleConfig._publicSaleMintCost >= 100),
            "Init: Invalid Token Cost"
        );
        require(block.timestamp <= _preSaleConfig._preSaleStartTime, "Init: Invalid PreSale Start Time");
        require(
            both(_preSaleConfig._preSaleDuration > 0, _publicSaleConfig._publicSaleDuration > 0),
            "Init: Sale duration>0"
        );
        require(
            both(
                _preSaleConfig._maxTokenPerMintPreSale > 0,
                _preSaleConfig._maxTokenPerMintPreSale <= _preSaleConfig._limitSupplyInPreSale
            ),
            "Init: Invalid maxTokenPerMint in presale"
        );

        require(_publicSaleConfig._maxTokenPerMintPublicSale > 0, "Init: Invalid MaxTokenPerMint of public sale");

        require(
            both(
                _publicSaleConfig._maxTokenPerPersonPublicSale <= _maxSupply,
                _publicSaleConfig._maxTokenPerPersonPublicSale >= _publicSaleConfig._maxTokenPerMintPublicSale
            ),
            "Init: Invalid MaxTokenPerPerson of public sale"
        );

        require(_signerAddress != address(0), "Init: Invalid SignerAddress");

        __ERC1155_init(_baseUri);
        __Ownable_init();

        name = _name;
        symbol = _symbol;
        saleType = _saleType;
        baseUri = _baseUri;
        maxSupply = _maxSupply;
        saleId = _saleId;

        preSaleMintCost = _preSaleConfig._preSaleMintCost;
        publicSaleMintCost = _publicSaleConfig._publicSaleMintCost;
        preSaleStartTime = _preSaleConfig._preSaleStartTime;
        preSaleEndTime = _preSaleConfig._preSaleStartTime + _preSaleConfig._preSaleDuration;
        publicSaleBufferDuration = _publicSaleConfig._publicSaleBufferDuration;
        publicSaleStartTime =
            _preSaleConfig._preSaleStartTime +
            _preSaleConfig._preSaleDuration +
            defaultPublicSaleBufferDuration +
            _publicSaleConfig._publicSaleBufferDuration;
        publicSaleEndTime = publicSaleStartTime + _publicSaleConfig._publicSaleDuration;
        maxTokenPerMintPreSale = _preSaleConfig._maxTokenPerMintPreSale;
        maxTokenPerMintPublicSale = _publicSaleConfig._maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _publicSaleConfig._maxTokenPerPersonPublicSale;
        limitSupplyInPreSale = _preSaleConfig._limitSupplyInPreSale;
        signerAddress = _signerAddress;
        version = 1;
        factory = msg.sender;
    }

    /**
    @notice This function is used to create Airdrop (give away NFTs)
    @dev It can only be called by owner  
    @param _list list of addresses  
    @param  shares sale shares in Airdrop
    */
    function createAirdrop(address[] calldata _list, uint256[2] calldata shares) external isApproved onlyOwner {
        _initiateAirdrop(_list, shares);
    }

    /**
    @notice This function is used to update version of contract
    @param _version version number
    */
    function setVersion(uint256 _version) external onlyOwner {
        version = _version;
    }
}