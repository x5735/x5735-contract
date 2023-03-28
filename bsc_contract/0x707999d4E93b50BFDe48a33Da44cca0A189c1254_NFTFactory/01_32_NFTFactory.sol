// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Sales/NFTWithoutPresaleWithoutRandomInstant.sol";
import "./Sales/NFTWithPresaleWithoutRandomInstant.sol";
import "./Sales/NFTWithoutPresaleWithRandomDelayed.sol";
import "./Sales/NFTWithPresaleWithRandomDelayed.sol";
import "./Interfaces/INFTSale.sol";

contract NFTFactory is Ownable {
    uint256 public version = 1;
    address public immutable nftWithoutPresaleWithoutRandomInstant;
    address public immutable nftWithPresaleWithoutRandomInstant;
    address public immutable nftWithoutPresaleWithRandomDelayed;
    address public immutable nftWithPresaleWithRandomDelayed;

    event SaleCreated(address clone, string saleID);

    event SetDropFee(address indexed nftDrop, address feeWallet, uint256 fee);

    event Approved(address approver, address nftDrop);

    mapping(string => bool) public isSaleidExists;

    mapping(address => bool) public isDropFeeSet;

    mapping(address=>bool) public isDropDeployed;

    NFTWithPresaleWithRandomDelayed.randomConfig internal rConfig;

    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    ) {
        require(_vrfCoordinator != address(0), "Invalid VRF");

        nftWithoutPresaleWithoutRandomInstant = address(new NFTWithoutPresaleWithoutRandomInstant());
        nftWithPresaleWithoutRandomInstant = address(new NFTWithPresaleWithoutRandomInstant());
        nftWithoutPresaleWithRandomDelayed = address(new NFTWithoutPresaleWithRandomDelayed());
        nftWithPresaleWithRandomDelayed = address(new NFTWithPresaleWithRandomDelayed());

        rConfig.vrfCoordinator = _vrfCoordinator;
        rConfig.link = _link;
        rConfig.keyHash = _keyHash;
        rConfig.fee = _fee;
    }

    /**
    @notice This function is used to deploy new sale contract  
    @param _name Collection name  
    @param _symbol Collection symbol  
    @param _saleCreator Collection creator name
    @param _presaleBaseUri Collection Base URI  
    @param _maxSupply Collection max supply  
    @param _saleId backend sale id   
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address of presale buyers   
    */
    function deployNFTWithoutPresaleWithoutRandomInstant(
        string memory _name,
        string memory _symbol,
        string memory _saleCreator,
        string memory _presaleBaseUri,
        uint256 _maxSupply,
        string memory _saleId,
        NFTWithoutPresaleWithoutRandomInstant.publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) external {
        require(!isSaleidExists[_saleId], "sale id exists");
        require(_publicSaleConfig._publicSaleStartTime!=0, "invalid sale start time");

        address clone = Clones.clone(nftWithoutPresaleWithoutRandomInstant);
        string memory _saleType = string(abi.encodePacked(_saleCreator, "NFTWithoutPresaleWithoutRandomInstant"));
        NFTWithoutPresaleWithoutRandomInstant(clone).__NFTWithoutPresaleWithoutRandomInstant_init(
            _name,
            _symbol,
            _saleType,
            _presaleBaseUri,
            _maxSupply,
            _saleId,
            _publicSaleConfig,
            _signerAddress
        );
        NFTWithoutPresaleWithoutRandomInstant(clone).transferOwnership(msg.sender);
        isSaleidExists[_saleId] = true;
        isDropDeployed[clone] = true;
        emit SaleCreated(clone, _saleId);
    }

    /**
    @notice This function is used to deploy new sale contract  
    @param _name Collection name  
    @param _symbol Collection symbol 
    @param _saleCreator Collection creator name
    @param _presaleBaseUri Collection Base URI  
    @param _maxSupply Collection max supply  
    @param _saleId backend sale id   
    @param _preSaleConfig Pre Sale configuration data   
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address of presale buyers   
    */
    function deployNFTWithPresaleWithoutRandomInstant(
        string memory _name,
        string memory _symbol,
        string memory _saleCreator,
        string memory _presaleBaseUri,
        uint256 _maxSupply,
        string memory _saleId,
        NFTWithPresaleWithoutRandomInstant.preSaleConfig memory _preSaleConfig,
        NFTWithPresaleWithoutRandomInstant.publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) external {
        require(!isSaleidExists[_saleId], "sale id exists");
        require(_preSaleConfig._preSaleStartTime!=0, "invalid presale start time");
        address clone = Clones.clone(nftWithPresaleWithoutRandomInstant);
        string memory _saleType = string(abi.encodePacked(_saleCreator, "NFTWithPresaleWithoutRandomInstant"));
        NFTWithPresaleWithoutRandomInstant(clone).__NFTWithPresaleWithoutRandomInstant_init(
            _name,
            _symbol,
            _saleType,
            _presaleBaseUri,
            _maxSupply,
            _saleId,
            _preSaleConfig,
            _publicSaleConfig,
            _signerAddress
        );
        NFTWithPresaleWithoutRandomInstant(clone).transferOwnership(msg.sender);
        isSaleidExists[_saleId] = true;
        isDropDeployed[clone] = true;
        emit SaleCreated(clone, _saleId);
    }

    /**
    @notice This function is used to deploy new sale contract  
    @param _name Collection name  
    @param _symbol Collection symbol
    @param _saleCreator Collection creator name  
    @param _baseUri Collection Base URI  
    @param _maxSupply Collection max supply 
    @param _saleId backend sale id   
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address of presale buyers
    */

    function deployNFTWithoutPresaleWithRandomdelayed(
        string memory _name,
        string memory _symbol,
        string memory _saleCreator,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId, // Sould not be duplicated
        NFTWithoutPresaleWithRandomDelayed.publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) external {
        require(!isSaleidExists[_saleId], "sale id exists");
        require(_publicSaleConfig._publicSaleStartTime!=0, "invalid sale start time");

        address clone = Clones.clone(nftWithoutPresaleWithRandomDelayed);
        string memory _saleType = string(abi.encodePacked(_saleCreator, "NFTWithoutPresaleWithRandomdelayed"));
        NFTWithoutPresaleWithRandomDelayed(clone).__NFTWithoutPresaleWithRandomDelayed_init(
            _name,
            _symbol,
            _saleType,
            _baseUri,
            _maxSupply,
            _saleId,
            _publicSaleConfig,
            _signerAddress,
            rConfig
        );
        NFTWithoutPresaleWithRandomDelayed(clone).transferOwnership(msg.sender);
        isSaleidExists[_saleId] = true;
        isDropDeployed[clone] = true;
        emit SaleCreated(clone, _saleId);
    }

    /**
    @notice This function is used to deploy new sale contract  
    @param _name Collection name  
    @param _symbol Collection symbol 
    @param _saleCreator Collection creator name  
    @param _baseUri Collection Base URI  
    @param _maxSupply Collection max supply 
    @param _saleId backend sale id   
    @param _preSaleConfig Pre Sale configuration data 
    @param _publicSaleConfig Public sale configuration data  
    @param _signerAddress Whitelist signer address of presale buyers
    */

    function deployNFTWithPresaleWithRandomdelayed(
        string memory _name,
        string memory _symbol,
        string memory _saleCreator,
        string memory _baseUri,
        uint256 _maxSupply,
        string memory _saleId,
        NFTWithPresaleWithRandomDelayed.preSaleConfig memory _preSaleConfig,
        NFTWithPresaleWithRandomDelayed.publicSaleConfig memory _publicSaleConfig,
        address _signerAddress
    ) external {
        require(!isSaleidExists[_saleId], "sale id exists");
        require(_preSaleConfig._preSaleStartTime!=0, "invalid presale start time");
 
        address clone = Clones.clone(nftWithPresaleWithRandomDelayed);
        string memory _saleType = string(abi.encodePacked(_saleCreator, "NFTWithPresaleWithRandomdelayed"));
        NFTWithPresaleWithRandomDelayed(clone).__NFTWithPresaleWithRandomDelayed_init(
            _name,
            _symbol,
            _saleType,
            _baseUri,
            _maxSupply,
            _saleId,
            _preSaleConfig,
            _publicSaleConfig,
            _signerAddress,
            rConfig
        );
        NFTWithPresaleWithRandomDelayed(clone).transferOwnership(msg.sender);
        isSaleidExists[_saleId] = true;
        isDropDeployed[clone] = true;
        emit SaleCreated(clone, _saleId);
    }

      /**
    @notice This function is used to set drop fees and feeReceiver wallet for nftdrop
    @param _nftDrop drop address  
    */
    function setDropFee(
        address _nftDrop,
        address _feeWallet,
        uint256 _fee
    ) external onlyOwner {
        require(isDropDeployed[_nftDrop], "nft drop is not deployed");
        require(_fee != 0, "fee should be not be 0");
        require(_fee < 10000, "fee<10000");
        require(_feeWallet != address(0), "invalid fee receiver");

        INFTSale(_nftDrop).setDropFee(_fee, _feeWallet);

        isDropFeeSet[_nftDrop] = true;

        emit SetDropFee(_nftDrop, _feeWallet, _fee);
    }

     /**
    @notice This function is used to approve deployed nftDrop
    @param _nftDrop drop address  
    */
    function setApproval(address _nftDrop) external onlyOwner {
        require(isDropDeployed[_nftDrop], "nft drop is not deployed");
        require(isDropFeeSet[_nftDrop], "invalid approval stage");

        INFTSale(_nftDrop).setDropApproval();

        emit Approved(msg.sender, _nftDrop);
    }

    /**
    @notice This function is used to update vrfCoordinator address  
    @param _vrfCoordinator Chain Link vrfCoordinator address  
    */
    function setVrfCoordinator(address _vrfCoordinator) external onlyOwner {
        require(_vrfCoordinator != address(0), "Invalid VRF");
        rConfig.vrfCoordinator = _vrfCoordinator;
    }

    /**
    @notice This function is used to update link token address  
    @param _link Chain Link link token address  
    */
    function setLinkTokenAddress(address _link) external onlyOwner {
        require(_link != address(0), "Invalid Link");
        rConfig.link = _link;
    }

    /**
    @notice This function is used to update key hash  
    @param _keyHash Chain Link random key hash  
    */
    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        rConfig.keyHash = _keyHash;
    }

    /**
    @notice This function is used to update fee  
    @param _fee fee
    */
    function setFee(uint256 _fee) external onlyOwner {
        rConfig.fee = _fee;
    }

    /**
    @notice This function is used to update version  
    @param _version version number
    */
    function setVersion(uint256 _version) external onlyOwner {
        version = _version;
    }
}