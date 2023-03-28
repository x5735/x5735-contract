// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Base/BaseNFTWithPresale.sol";
import "../Base/BaseNFTDelayed.sol";
import "../Base/BaseNFTWithRandom.sol";

contract NFTWithPresaleWithRandomDelayed is BaseNFTWithPresale, BaseNFTDelayed, BaseNFTWithRandom {
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
    @param _randomConfig random number configuration data  
    */
    function __NFTWithPresaleWithRandomDelayed_init(
        string memory _name,
        string memory _symbol,
        string memory _saleType,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId,
        preSaleConfig memory _preSaleConfig,
        publicSaleConfig memory _publicSaleConfig,
        address _signerAddress,
        randomConfig memory _randomConfig
    ) external initializer {
        require(both(_maxSupply > 0, _maxSupply <= 100000), "Init: Invalid max supply");

        require(
            both(_preSaleConfig._limitSupplyInPreSale > 0, _preSaleConfig._limitSupplyInPreSale <= _maxSupply),
            "Init: Invalid presale supply"
        );

        require(block.timestamp <= _preSaleConfig._preSaleStartTime, "Init: Invalid PreSale Start Time");

        require(
            both(_preSaleConfig._preSaleDuration > 0, _publicSaleConfig._publicSaleDuration > 0),
            "Init: Sale duration>0"
        );

        require(
            both(_preSaleConfig._preSaleMintCost >= 100, _publicSaleConfig._publicSaleMintCost >= 100),
            "Init: Invalid Token Cost"
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
                _publicSaleConfig._maxTokenPerPersonPublicSale >= _publicSaleConfig._maxTokenPerMintPublicSale,
                _publicSaleConfig._maxTokenPerPersonPublicSale <= _maxSupply
            ),
            "Init: Invalid MaxTokenPerPerson of public sale"
        );

        require(_signerAddress != address(0), "Init: Invalid SignerAddress");

        __ERC1155_init(_baseUri);
        __Ownable_init();
        __VRFConsumerBase_init(_randomConfig.vrfCoordinator, _randomConfig.link);

        name = _name;
        symbol = _symbol;
        saleType = _saleType;
        baseUri = _baseUri;
        maxSupply = _maxSupply;
        saleId = _saleId;
        keyHash = _randomConfig.keyHash;
        fee = _randomConfig.fee;

        preSaleMintCost = _preSaleConfig._preSaleMintCost;
        publicSaleMintCost = _publicSaleConfig._publicSaleMintCost;
        preSaleStartTime = _preSaleConfig._preSaleStartTime;
        unchecked {
            preSaleEndTime = preSaleStartTime + _preSaleConfig._preSaleDuration;
            publicSaleBufferDuration = _publicSaleConfig._publicSaleBufferDuration;
            publicSaleStartTime =
                preSaleEndTime +
                defaultPublicSaleBufferDuration +
                _publicSaleConfig._publicSaleBufferDuration;
            publicSaleEndTime = publicSaleStartTime + _publicSaleConfig._publicSaleDuration;
        }
        maxTokenPerMintPreSale = _preSaleConfig._maxTokenPerMintPreSale;
        maxTokenPerMintPublicSale = _publicSaleConfig._maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _publicSaleConfig._maxTokenPerPersonPublicSale;
        limitSupplyInPreSale = _preSaleConfig._limitSupplyInPreSale;
        signerAddress = _signerAddress;
        version = 1;
        factory = msg.sender;
    }

    /**
    @notice This function is used to reveal the token can only be called by owner  
    @dev TokensRevealed and URI event is emitted  
    */
    function revealTokens(string memory _uri) external onlyOwner publicSaleEnded {
        require(isrequestfulfilled, "random number to be assigned");
        _revealTokens();
        _updateURI(_uri);
    }

    /**
    @notice This function is used to get random asset id  
    @return assetID Random assetID  
    */
    function getAssetId(uint256 _tokenID) external view returns (uint256) {
        require(revealed, "reveal token first");

        return _getAssetId(_tokenID);
    }

    /**
    @notice This function is used to create Airdrop  
    @dev It can only be called by owner  
    @param _list list of addresses  
    @param _shares preSaleShare and publicsale share in Airdrop
    */
    function createAirdrop(address[] calldata _list, uint256[2] calldata _shares) external isApproved onlyOwner {
        require(!revealed, "Airdrop: Invalid action after reveal");

        _initiateAirdrop(_list, _shares);
    }

    /**
    @notice This function is used to update version of contract
    @param _version version number
    */
    function setVersion(uint256 _version) external onlyOwner {
        version = _version;
    }
}