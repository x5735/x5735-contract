// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract NFT is Initializable, ERC721Upgradeable, ERC721RoyaltyUpgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
  address private MARKETPLACE_ADDRESS;
  string baseUri;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() initializer public {
    __ERC721_init("EYEC NFT", "EYECN");
    __ERC721URIStorage_init();
    __Ownable_init();
  }

  function _baseURI() internal view override returns (string memory) {
    return baseUri;
  }

  function safeMintNFT(uint96 _royaltyAmount, uint256 _nftId, uint256 _sellPrice, address _feesReceiverAddress) public returns(uint256) {
    address to = msg.sender;
    require(to == MARKETPLACE_ADDRESS, "Sorry, you cannot call this function.");

    require(!super._exists(_nftId), "Sorry, this NFT already exists.");

    super._setTokenRoyalty(_nftId, _feesReceiverAddress, _royaltyAmount);
    super.royaltyInfo(_nftId, _sellPrice);
    super._safeMint(to, _nftId);
    super._setTokenURI(_nftId, StringsUpgradeable.toString(_nftId));

    return _nftId;
  }

  function setMarketplaceAddress(address _address) external onlyOwner {
    require(_address != address(0), "Sorry, the address can not be equal to zero.");

    MARKETPLACE_ADDRESS = _address;
  }

  // The following functions are overrides required by Solidity.

  function _burn(uint256 _nftId)
    internal
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable)
  {
    super._burn(_nftId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721RoyaltyUpgradeable) returns (bool) {
    return interfaceId == type(ERC721RoyaltyUpgradeable).interfaceId || super.supportsInterface(interfaceId);
}

  function tokenURI(uint256 _nftId)
    public
    view
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    returns (string memory)
  {
    return super.tokenURI(_nftId);
  }

  function setBaseUri(string calldata _baseUri) external onlyOwner
  {
    baseUri = _baseUri;
  }
}