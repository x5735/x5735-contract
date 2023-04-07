// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


contract LuckyBunnies is Ownable, ReentrancyGuard, ERC721 {
    uint public tokenId;    
    uint public bunnieammount = 50;
    uint256 public mintingprice = 379e18;
    mapping(uint => bool) public isBunnie;

    constructor() ERC721("Lucky Bunnies", "LB") {
        
        
       
    }



    function mint() public  nonReentrant{
        IERC20 tokenAddress = IERC20(0x55d398326f99059fF775485246999027B3197955);
        require(tokenId < bunnieammount, "All 50 tokens have been minted");
        require(tokenAddress.allowance(msg.sender, address(this)) >= mintingprice, "Insuficient Allowance");
        require (tokenAddress.balanceOf(msg.sender) >= mintingprice, "You don't have enough tokens");   
        _safeMint(msg.sender, tokenId);
        tokenId = tokenId + 1;
    }

    function makeBunnie(uint _tokenId) external onlyOwner {       
        isBunnie[_tokenId] = true;
    }

    function tokenURI(uint256 _tokenId, string memory bunnie)  public view returns (string memory) {
        string memory json1 = '{"name": "Lucky Bunnies", "description": "Lucky Bunnies", "image": "https://ipfs.sparklifesps.com/ipfs/';
        string memory json2;
        // Upload images to IPFS at https://nft.storage
        if (isBunnie[_tokenId] == false) json2 = 'QmcP6piPT48sZsoQradugYcTeUi7Cw5UrGFvauTcvFdMqb"}'; 
        if (isBunnie[_tokenId] == true) json2 = '"}'; 
        string memory json = string.concat(json1, bunnie, json2);
        string memory encoded = Base64.encode(bytes(json));
        return string(abi.encodePacked('data:application/json;base64,', encoded));
    }
    function withdraw(address _tokenContract) public onlyOwner {
        IERC20 tokenContract = IERC20(_tokenContract);
        uint256 ownerBalance = tokenContract.balanceOf(address(this));
        require(ownerBalance > 0, "Owner has not balance to withdraw");
        require(tokenContract.transfer(msg.sender, ownerBalance));
    }

    function updateBunnieammount(uint ammount) external onlyOwner {
        bunnieammount = ammount;
    }
    function updateBunnieprice(uint price) external onlyOwner {
        mintingprice = price;
    }
}