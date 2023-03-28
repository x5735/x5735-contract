// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DefiSniperzNft is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter public currentTokenId;

    bool public publicMintOpen = false;
    address admin;
    address usdcTokenAddress   = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    
    address public teamWallet         = 0xE88B1077DBa328b35Ad963Cf7c0154866446Cd61;
    address public portfolioWallet    = 0x8e3057ACbE33Eb464fd5936b90c96dCC056b127d;
    //
    IERC20 usdcTokenInstance;

    mapping(address => bool) public whitelist;
    mapping(address => bool) public excludedList;
    mapping(address => uint256) public ownedBy;

    event Sale(address from, address to);
    
    constructor() ERC721("Defi Sniperz Founders NFT Collection", "DSNPRZ") {
        admin = msg.sender;
        usdcTokenInstance = IERC20(usdcTokenAddress);
    }

    modifier adminOnly {
        require(msg.sender == admin, "Admin only");
        _;
    }

    function SetPublicMintState( bool state) public adminOnly {
        publicMintOpen = state;
    }

    function SetRoyaltyExclusion(address user, bool state) public adminOnly {
        excludedList[user] = state;
    }

    function writeWhitelist(address user, bool state) public adminOnly{
        whitelist[user] = state;
    }

    function writeWhitelistBuffer(address [] memory whitelistArray) public adminOnly{
        for (uint i = 0; i < whitelistArray.length; i++) {
            whitelist[whitelistArray[i]] = true;
        }
    }

    function tokenURI(uint256 _tokenId) override public pure returns(string memory) {
        return string(
                abi.encodePacked(
                        "ipfs.io/ipfs/QmSL7AZgsJY5iUS7YfUYp52RhEPWFeWjdLx5K6NMjcMiXm/",
                        Strings.toString(_tokenId),
                        ".json"
                    )
            );
    }

    function mint() public returns (uint256){
        //close mint at 200th nft
        if (currentTokenId.current() >= 200){
            revert("NFTs Sold Out");
        }
        //ether is base unit. 
        if (publicMintOpen == false) {
            require(whitelist[msg.sender] == true,"Public Mint not yet Open");    
        }
        uint256 mintPrice = whitelist[msg.sender] == true ? 350 ether : 400 ether;
        require(usdcTokenInstance.transferFrom(msg.sender,address(this),mintPrice),"NFT mint Failed");
        // removed user from whitelist once they mint
        if(whitelist[msg.sender] == true){
            whitelist[msg.sender] = false;
        }
        //Fees
        uint256 team = mintPrice * 10 / 100;
        uint256 portfolio = mintPrice - team;
        require(usdcTokenInstance.transfer(teamWallet, team), "Team transfer failed");
        require(usdcTokenInstance.transfer(portfolioWallet, portfolio), "Portfolio transfer failed");
        //
        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(msg.sender, newItemId);
        ownedBy[msg.sender] = newItemId;
        
        return newItemId;
    }

    function removeExcessUsdc() public adminOnly {
        uint256 balance = usdcTokenInstance.balanceOf(address(this));
        usdcTokenInstance.transfer(portfolioWallet, balance);
    }

    function changeAdmin(address newAdmin) public adminOnly {
        admin = newAdmin;
    }

    function _payRoyalty() internal {
        //USDC approve must occur before transfer
        //10% of public mint
        require(usdcTokenInstance.transferFrom(msg.sender,teamWallet,40 ether),"NFT Royalty Failed");
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        if (excludedList[from] == false) {
            _payRoyalty();
        }
        emit Sale(from, to);
        ownedBy[from] = 0;
        ownedBy[to] = tokenId;
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (excludedList[from] == false) {
            _payRoyalty();            
        }
        emit Sale(from, to);
        
        ownedBy[from] = 0;
        ownedBy[to] = tokenId;
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        if (excludedList[from] == false) {
            _payRoyalty();            
        }
        emit Sale(from, to);

        ownedBy[from] = 0;
        ownedBy[to] = tokenId;
        _safeTransfer(from, to, tokenId, _data);
    }

}