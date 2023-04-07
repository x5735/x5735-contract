// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CrocobitNFT is ERC721, Pausable, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    IERC20 public USDT;

    uint constant maxCount = 10000;
    string public uri = "https://crocobit.net/meta/";
    uint public price;
    uint public totalSupply; 
    mapping (uint => uint) public typeNFT;

    event minted (address indexed sender, uint indexed id, uint indexed typeNFT);

    function mint(uint _count, uint _type) public {
        require(totalSupply <= maxCount);

        uint _amount = price * _count;
        USDT.transferFrom(msg.sender, address(this), _amount);
        
        for (uint i = 0; i < _count; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
            typeNFT[tokenId] = _type;
            totalSupply++;

            emit minted(msg.sender, tokenId, _type);
        }
    }

    function setPrice(uint _price) public onlyOwner {
        price = _price;
    }

    function setURI(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    function setUSDTAddress(IERC20 _address) public onlyOwner {
        USDT = _address;
    }

    function withdrawUSDT(uint _amount) public onlyOwner {
        USDT.transfer(msg.sender, _amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _baseURI() internal view override returns (string memory) {
        return uri;
    }

    constructor() ERC721("Crocobit NFT", "Crocobit") {}
}