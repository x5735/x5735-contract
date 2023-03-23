// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";

import "./common/meta-transactions/ContentMixin.sol";
import "./common/meta-transactions/NativeMetaTransaction.sol";

contract OwnableDelegateProxy {}

/**
 * Used to delegate ownership of a contract to another address, to save on unneeded transactions to approve contract use for users
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract BigEyeNFT is ERC721URIStorage, ERC2981, ContextMixin, NativeMetaTransaction, PullPayment, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    uint256 private maxtokenURIs;
    Counters.Counter private _tokenIds;
    Counters.Counter private _burntTokenIds;
    address proxyRegistryAddress;
    string public baseTokenURI;
    string public contractURI;
    uint8 constant private totalTokenClass = 25;
    mapping(address=>mapping(uint8=>bool)) public isClassWhitelisted;
    mapping(address=>mapping(uint8=>bool)) public isClassMinted;
    mapping(uint256=>uint8) public classForTokenId;
    mapping(uint8=>uint256) public mintFee;
    uint256 private seed;

    event Whitelisted(address minter, uint8 class, bool whitelist);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress,
        string memory _baseTokenURI,
        string memory _contractURI,
        uint256 _maxtokenURIs
    ) ERC721(_name, _symbol) {
        proxyRegistryAddress = _proxyRegistryAddress;
        _setDefaultRoyalty(msg.sender, 100);
        _initializeEIP712(_name);
        baseTokenURI = _baseTokenURI;
        contractURI=_contractURI;
        maxtokenURIs=_maxtokenURIs;
    }

    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    function setContractURI(string memory _contractURI) public onlyOwner {
        contractURI = _contractURI;
    }

    function updateMintFee(uint8 _class, uint256 _mintFee) external onlyOwner {
        require(_class<=totalTokenClass && _class>0, "class range is 1 ~ 25");
        mintFee[_class] = _mintFee;
    }

    function whitelistForMint(address _minter, uint8 _class, bool _whitelist) external onlyOwner {
        require(_class<=totalTokenClass && _class>0, "class range is 1 ~ 25");
        require(_whitelist!=isClassWhitelisted[_minter][_class], "Whitelist status is the same");
        require(!isClassMinted[_minter][_class], "Already minted");
        isClassWhitelisted[_minter][_class] = _whitelist;
        emit Whitelisted(_minter, _class, _whitelist);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current()-_burntTokenIds.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _burntTokenIds.increment();
        _resetTokenRoyalty(tokenId);
    }

    function burn(uint256 tokenId)
        external {
        require(ERC721.ownerOf(tokenId) == _msgSender(), "Only owner can burn");
        _burn(tokenId);
    }

    function generateTokenURI(uint8 _class) internal returns(string memory _uri){
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, seed)));
        seed = randomNumber;
        return string.concat(Strings.toString(_class), '_', Strings.toString(randomNumber*maxtokenURIs));
    }

    function mintNFT(address recipient, uint8 _class)
        public payable
        returns (uint256) {
        require(_class > 0 && _class <= totalTokenClass, "class range is 1 ~ 25");
        require(isClassWhitelisted[_msgSender()][_class], "Not whitelisted");
        require(!isClassMinted[_msgSender()][_class], "Already minted");
        require(msg.value == mintFee[_class], "Transaction value did not equal the mint price");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, generateTokenURI(_class));
        isClassMinted[_msgSender()][_class]=true;
        return newItemId;
    }

    function mintNFTWithRoyalty(address recipient, uint8 _class, address royaltyReceiver, uint96 feeNumerator)
        public payable
        returns (uint256) {
        uint256 tokenId = mintNFT(recipient, _class);
        _setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);

        return tokenId;
    }

    function withdrawPayments(address payable payee) public override onlyOwner virtual {
        super.withdrawPayments(payee);
    }
}