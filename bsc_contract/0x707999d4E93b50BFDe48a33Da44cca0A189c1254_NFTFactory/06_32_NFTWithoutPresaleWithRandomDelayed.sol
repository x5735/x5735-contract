// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Base/BaseNFTWithoutPresale.sol";
import "../Base/BaseNFTDelayed.sol";
import "../Base/BaseNFTWithRandom.sol";

contract NFTWithoutPresaleWithRandomDelayed is BaseNFTWithoutPresale, BaseNFTDelayed, BaseNFTWithRandom {
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
    function __NFTWithoutPresaleWithRandomDelayed_init(
        string memory _name,
        string memory _symbol,
        string memory _saleType,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId,
        publicSaleConfig memory _publicSaleConfig,
        address _signerAddress,
        randomConfig memory _randomConfig
    ) public initializer {
        require(both(_maxSupply > 0, maxSupply <= 100000), "Init: Invalid max supply");
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
        require(revealed, "reveal the token first");
        return _getAssetId(_tokenID);
    }

    /**
    @notice This function is used to create Airdrop  
    @dev It can only be called by owner  
    @param _list list of addresses  
    @param _shares public Sale Shares in Airdrop 
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