//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract WOWNFTWL is Ownable, ERC721, ERC721Enumerable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 public timestamp;
    uint256 public USDTprice;
    uint256 public MMPROprice;
    uint256 public limitSupply;
    uint256 public lastSale;
    uint256 public mmproSold;
    uint256 public usdtSold;
    uint256 public pauseTime = 300;
    address public usdtTokenAddress;
    address public mmproTokenAddress;
    bool public isPaused;
    bool public isMMPRO = true;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _timestamp,
        uint256 _USDTprice,
        uint256 _MMPROprice,
        uint256 _limitSupply,
        address _usdtTokenAddress,
        address _mmproTokenAddress
    ) ERC721(name, symbol) {
        timestamp = _timestamp;
        USDTprice = _USDTprice;
        MMPROprice = _MMPROprice;
        limitSupply = _limitSupply;
        usdtTokenAddress = _usdtTokenAddress;
        mmproTokenAddress = _mmproTokenAddress;
    }


    function mintWithMMPro() public {
        require(!isPaused, "Paused");
        require(block.timestamp >= timestamp, "Sale has not started yet");
        require(totalSupply() < limitSupply, "Sale has already ended");
        require(isMMPRO, "Cannot purchase with MMPro at this time");

        IERC20 mmproToken = IERC20(mmproTokenAddress);
        uint256 balance = mmproToken.balanceOf(msg.sender);
        require(balance >= MMPROprice, "Insufficient MMPRO balance");

        uint256 tokenId = _tokenIdCounter.current();              
        mmproToken.transferFrom(msg.sender, address(this), MMPROprice);
        _safeMint(msg.sender, tokenId);
        lastSale = block.timestamp;
        mmproSold++;
        _tokenIdCounter.increment();
        
        if (mmproSold == usdtSold + 5) {
            timestamp = block.timestamp + pauseTime; // 5-minute break
            isMMPRO = false; // §á§Ö§â§Ö§Ü§Ý§ð§é§Ú§ä§î§ã§ñ §ß§Ñ §â§Ö§Ø§Ú§Þ §á§â§à§Õ§Ñ§Ø§Ú §Ù§Ñ USDT
        }
    }

    function mintWithUSDT(uint256 _usdtAmount) public {
        require(!isPaused, "Paused");
        require(block.timestamp >= timestamp, "Sale has not started yet");
        require(totalSupply() < limitSupply, "Sale has already ended");
        require(!isMMPRO, "Cannot purchase with USDT at this time");

        IERC20 usdtToken = IERC20(usdtTokenAddress);
        uint256 balance = usdtToken.balanceOf(msg.sender);
        require(balance >= _usdtAmount, "Insufficient USDT balance");

        uint256 tokenId = _tokenIdCounter.current();        
        usdtToken.transferFrom(msg.sender, address(this), _usdtAmount);
        _safeMint(msg.sender, tokenId);
        lastSale = block.timestamp;
        usdtSold++;
        _tokenIdCounter.increment();
        
        if (usdtSold == mmproSold) {
            timestamp = block.timestamp + pauseTime; // 5-minute break
            isMMPRO = true; // §á§Ö§â§Ö§Ü§Ý§ð§é§Ú§ä§î§ã§ñ §ß§Ñ §â§Ö§Ø§Ú§Þ §á§â§à§Õ§Ñ§Ø§Ú §Ù§Ñ MMPRO
        }
    }


    function setSaleStartTime(uint256 _timestamp) public onlyOwner {
        timestamp = _timestamp;
    }
    
    function setPriceInUSDT(uint256 _uprice) public onlyOwner {
        USDTprice = _uprice;
    }

    function setPriceInMMPRO(uint256 _mprice) public onlyOwner {
        MMPROprice = _mprice;
    }

    function setLimitSupply(uint256 _limitSupply) public onlyOwner {
        limitSupply = _limitSupply;
    }

    function setPaused(bool paused) external onlyOwner {
        isPaused = paused;
    }

    function setPauseTime(uint256 _pauseTime) external onlyOwner {
        pauseTime = _pauseTime;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function withdrawExtraTokens(address token, uint256 amount, address withdrawTo) external onlyOwner {
        IERC20(token).transferFrom(address(this), withdrawTo, amount);
    }
}