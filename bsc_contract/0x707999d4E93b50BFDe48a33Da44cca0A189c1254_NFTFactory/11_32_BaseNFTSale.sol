// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./BaseNFT.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract BaseNFTSale is BaseNFT {
    using ECDSA for bytes32;

    /** @notice total mint count of collection by referral */
    uint256 public totalMintReferral;

    /** @notice backend saleid of drop */
    string public saleId;

    /** @notice Cost to mint one token in pubic sale */
    uint256 public publicSaleMintCost;

    /** @notice Maximum No of token can be purchased by user in single tx in public sale  */
    uint256 public maxTokenPerMintPublicSale;

    /** @notice Maximum No of token can be purchased by user in one public sale  */
    uint256 public maxTokenPerPersonPublicSale;

    /** @notice Hash map to keep count of token minted by buyer in public sale */
    mapping(address => uint256) public publicsalerListPurchases;

    /** @notice Hash map to keep count of earnings of affiliated user */
    mapping(address => uint256) public affiliatedUserBalance;

    /** @notice total earnings of all affiliated users */
    uint256 public affiliatedWei;

    /** @notice address of the signer */
    address public signerAddress;

    /** @notice address of the feeReceiver */
    address public feeReceiver;

    /** @notice nftDrop factory address */
    address public factory;

    /** @notice nftDrop fee set by the factory owner or admin*/
    uint256 public dropFee;

    /** @notice nftDrop fee collected */
    uint256 public feesCollected;

    /** @notice a variable for tracking whether the nftDrop is approved by the admin or not */
    uint256 public isDropApproved;

    modifier publicSaleLive() {
        _onlyWhenPublicSaleLive();
        _;
    }

    modifier publicSaleEnded() {
        _onlyWhenPublicSaleEnded();
        _;
    }

    modifier isFactory() {
        require(msg.sender == factory, "!auth");
        _;
    }

    modifier isApproved() {
        require(isDropApproved == uint256(1), "!approved");
        _;
    }

    /**
    @notice Event for uri change  
    @param uri New uri of the collection  
    */
    event URI(string uri);

    /**
    @notice This function is used to buy and mint nft in public sale  
    @param tokenQuantity The token quantity that buyer wants to mint  
    */
    function _publicSaleMint(uint256 tokenQuantity) internal isApproved publicSaleLive {
        verifyTokenQuantity(tokenQuantity);
        _mintTo(msg.sender, tokenQuantity);

        unchecked {
            publicsalerListPurchases[msg.sender] += tokenQuantity;
        }
    }

    /**
    @notice This function is used to buy and mint nft in public sale for affiliation feature  
    @param tokenQuantity The token quantity that buyer wants to mint  
    @param affiliatedUser The affiliated user address  
    @param commission The commission percentage that will be paid to affiliated user  
    @param signature The signature sent by the buyer  
    */
    function _publicSaleMintAffiliated(
        uint256 tokenQuantity,
        address affiliatedUser,
        uint256 commission,
        bytes memory signature
    ) internal isApproved publicSaleLive {
        require(affiliatedUser != address(0), "!user");

        bytes32 hash = hashforPublicSaleAffiliated(msg.sender, affiliatedUser, commission);
        require(matchAddressSigner(hash, signature), "invalid-signature");

        verifyTokenQuantity(tokenQuantity);
        _mintTo(msg.sender, tokenQuantity);
        unchecked {
            totalMintReferral += tokenQuantity;
            uint256 receivedAmount = ((publicSaleMintCost * commission) * tokenQuantity) / 100;
            affiliatedUserBalance[affiliatedUser] += receivedAmount;
            affiliatedWei += receivedAmount;
            publicsalerListPurchases[msg.sender] += tokenQuantity;
        }
    }

    /**
    @notice This function is used to withdraw ether from contract  
    */
    function withdrawWei(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Amount>0");
        uint256 totalDropFee;
        unchecked{
        require(address(this).balance - affiliatedWei >= _amount, "Not enough eth");
        totalDropFee = (_amount * dropFee)/10000;
        }
        (bool success, ) = msg.sender.call{value: _amount-totalDropFee}("");
        require(success, "Tx failed.");
        if (totalDropFee != 0) {
            (bool flag, ) = payable(feeReceiver).call{value: totalDropFee}("");
            require(flag, "Fee:Tx failed.");
            unchecked{
            feesCollected += totalDropFee;
            }
        }
    }

    /**
    @notice This function is used to withdraw affiliated user ether from contract  
    */
    function withdrawAffiliatedFunds(address[] memory affiliatedUser) external onlyOwner publicSaleEnded nonReentrant {
        checkAffiliatedFunds(affiliatedUser);
        uint256 balance;
        uint256 sum;
        uint256 totalDropFee;
        uint256 _fee;
        for (uint256 i; i < affiliatedUser.length; i = unchecked_inc(i)) {
            balance = affiliatedUserBalance[affiliatedUser[i]];
            unchecked{
            _fee = (balance * dropFee) / 10000;
            affiliatedUserBalance[affiliatedUser[i]] = 0;
            }
            (bool success, ) = msg.sender.call{value: balance - _fee}("");
            require(success, "Tx failed.");
            unchecked {
                sum += balance;
                totalDropFee += _fee;
            }
        }
        unchecked {
            affiliatedWei -= sum;
        }

        if (totalDropFee != 0) {
            (bool flag, ) = payable(feeReceiver).call{value: totalDropFee}("");
            require(flag, "Fee:Tx failed.");
            unchecked{
            feesCollected += totalDropFee;
            }
        }
    }

    /**
    @notice This function is used to transfer affiliated user ether from contract  
    */
    function transferAffiliatedFunds(address[] memory affiliatedUser) external onlyOwner publicSaleEnded {
        checkAffiliatedFunds(affiliatedUser);
        uint256 balance;
        uint256 sum;
        uint256 totalDropFee;
        uint256 _fee;
        for (uint256 i; i < affiliatedUser.length; i = unchecked_inc(i)) {
            balance = affiliatedUserBalance[affiliatedUser[i]];
            unchecked{
            _fee = (balance * dropFee) / 10000;
            affiliatedUserBalance[affiliatedUser[i]] = 0;
            }
            (bool success, ) = affiliatedUser[i].call{value: balance - _fee}("");
            require(success, "Transfer failed.");
            unchecked {
                sum += balance;
                totalDropFee += _fee;
            }
        }
        unchecked {
            affiliatedWei -= sum;
        }

        if (totalDropFee != 0) {
            (bool flag, ) = payable(feeReceiver).call{value: totalDropFee}("");

            require(flag, "Fee:Tx failed.");
            unchecked{
            feesCollected += totalDropFee;
            }
        }
    }

    /**
    @notice This function is used to update signer address  
    */
    function updateSignerAddress(address _signerAddress) external onlyOwner {
        require(_signerAddress != address(0), "!signer");
        signerAddress = _signerAddress;
    }

    /**
    @notice This function is used to update uri  
    */
    function updateURI(string memory _uri) public onlyOwner {
        _updateURI(_uri);
    }

    /**
    @dev can be called from factory contract
    @notice This function is used to set drop fee and fee receiver wallet  
    */
    function setDropFee(uint256 _fee, address _wallet) external isFactory {
        dropFee = _fee;
        feeReceiver = _wallet;
    }

       /**
    @dev can be called from factory contract
    @notice This function is used to approve the nftDrop    */
    function setDropApproval() external isFactory {
        require(isDropApproved == uint256(0), "already approved");
        isDropApproved = uint256(1);
    }

    // ============================ Getter Functions ============================

    /**
    @notice This function is used to check if public sale is started  
    @return bool Return true if public is started or not  
    */
    function isPublicSaleLive() public view returns (bool) {
        return both(block.timestamp >= publicSaleStartTime, block.timestamp <= publicSaleEndTime);
    }

    function _onlyWhenPublicSaleLive() internal view {
        require(isPublicSaleLive(), "Public Sale-not live");
    }

    function _onlyWhenPublicSaleEnded() internal view {
        require(block.timestamp >= publicSaleEndTime, "public sale not yet ended");
    }

    /**
    @notice This function is used to get next tokenId 
    @return uint256 tokenID  
    */
    function getNextToken() internal returns (uint256) {
        require(totalMint <= maxSupply, "exceed max Supply");
        _incrementTokenId();
        return currentTokenId;
    }

    /**
    @dev This function is used to check if each affiliated user does have user balance or not   
    @param affiliatedUser array of affiliation user address  
    */
    function checkAffiliatedFunds(address[] memory affiliatedUser) public view {
        require(both(affiliatedUser.length != 0, affiliatedWei != 0), "Nothing to withdraw");
        for (uint256 i; i < affiliatedUser.length; i = unchecked_inc(i)) {
            string memory errorString = string(abi.encodePacked("No balance to transfer for ", affiliatedUser[i]));
            require(affiliatedUserBalance[affiliatedUser[i]] != 0, errorString);
        }
    }

    /**
    @dev This function is used to verify the whitelisted buyer using signature  
    @param hash The hash message generated by the function hashMessage  
    @param signature The signature sent by the buyer  
    @return boolean value true if the signature is verified else false  
    */
    function matchAddressSigner(bytes32 hash, bytes memory signature) public view returns (bool) {
        return signerAddress == hash.recover(signature);
    }

    /**
    @notice This internal function is used to update URI  
    */
    function _updateURI(string memory _uri) internal {
        _setURI(_uri);
        baseUri = _uri;
        emit URI(_uri);
    }

    /**
    @dev This internal function is used to verify the token quantity entered by buyer 
    @param _tokenQuantity token quantity entered by the buyer 
    */
    function verifyTokenQuantity(uint256 _tokenQuantity) internal {
        unchecked {
            require(both(_tokenQuantity > 0, _tokenQuantity <= maxTokenPerMintPublicSale), "Invalid Token Quantity");
            require((totalMint + _tokenQuantity) <= maxSupply, "exceed max supply.");
            require((publicSaleMintCost * _tokenQuantity) <= msg.value, "pay minimum token price");
            require(
                publicsalerListPurchases[msg.sender] + _tokenQuantity <= maxTokenPerPersonPublicSale,
                "exceed maximum allowed limit"
            );
        }
    }

    /**
    @dev This internal function is used to mint token quantity to receiver 
    @param tokenQuantity token quantity entered by the buyer 
    */
    function _mintTo(address receiver, uint256 tokenQuantity) internal {
        uint256 currentId;

        for (uint256 i; i < tokenQuantity; i = unchecked_inc(i)) {
            currentId = getNextToken();
            totalMint = unchecked_inc(totalMint);
            _mint(receiver, currentId, 1, "0x");
        }
    }

    // ============================ Utility Functions ============================

    /**
    @dev This function is used to generate hash message in case of affiliated buy of public sale 
    @param sender The address of the NFT recipient
    @param affiliatedUser The affiliated user address
    @param commission The commission percentage that will be paid to affiliated user
    @return hash generated by the function
    */
    function hashforPublicSaleAffiliated(
        address sender,
        address affiliatedUser,
        uint256 commission
    ) public view returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, block.chainid, affiliatedUser, commission, saleId, address(this)))
            )
        );
        return hash;
    }

    /**
    @dev This function is used to generate hash message during presale buy with whitelisted address
    @param sender The address of the NFT recipient
    @param tokenQuantity tokenQuantity
    @return hash generated by the function
    */
    function hashforPresale(address sender, uint256 tokenQuantity) public view returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, block.chainid, tokenQuantity, saleId, address(this)))
            )
        );
        return hash;
    }

    /**
    @dev This function is used to generate hash message during presale buy with affiliated link
    @param sender The address of the NFT recipient
    @param tokenQuantity tokenQuantity
    @param affiliatedUser The affiliated user address
    @param commission The commission percentage that will be paid to affiliated user
    @return hash generated by the function
    */
    function hashforPresaleAffiliated(
        address sender,
        uint256 tokenQuantity,
        address affiliatedUser,
        uint256 commission
    ) public view returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        sender,
                        block.chainid,
                        tokenQuantity,
                        affiliatedUser,
                        commission,
                        saleId,
                        address(this)
                    )
                )
            )
        );
        return hash;
    }
}