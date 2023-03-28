// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./BaseNFTSale.sol";
import "./BaseNFTAirdrop.sol";

contract BaseNFTWithPresale is BaseNFTSale, BaseNFTAirdrop {
    struct preSaleConfig {
        uint256 _preSaleMintCost;
        uint256 _preSaleStartTime;
        uint256 _preSaleDuration;
        uint256 _maxTokenPerMintPreSale;
        uint256 _limitSupplyInPreSale;
    }

    struct publicSaleConfig {
        uint256 _publicSaleMintCost;
        uint256 _publicSaleBufferDuration;
        uint256 _publicSaleDuration;
        uint256 _maxTokenPerMintPublicSale;
        uint256 _maxTokenPerPersonPublicSale;
    }

    /** @notice Cost to mint one token in presale */
    uint256 public preSaleMintCost;

    /**  @notice Time when presale starts */
    uint256 public preSaleStartTime;

    /** @notice Time at which preSale end, calculated preSaleStartTime + preSaleDuration */
    uint256 public preSaleEndTime;

    /** @notice Default buffer time between presale and public sale, constant 30 seconds */
    uint256 internal constant defaultPublicSaleBufferDuration = 30;

    /** @notice Buffer time to add between presale and public sale i.e 30 + something... */
    uint256 public publicSaleBufferDuration;

    /** @notice Maximum No of token can be purchased by user in single tx in pre sale */
    uint256 public maxTokenPerMintPreSale;

    /** @notice Pre Sale supply limit */
    uint256 public limitSupplyInPreSale;

    /** @notice Hash map to keep count of token minted by buyer in pre sale */
    mapping(address => uint256) public presalerListPurchases;

    modifier preSaleEnded() {
        _onlyWhenPresaleEnded();
        _;
    }

    // modifier saleCreated() {
    //     require(preSaleStartTime != 0, "Sale not created");
    //     require(publicSaleStartTime != 0, "Sale not created");
    //     _;
    // }

    modifier isSaleOff() {
        _isSaleOff();
        _;
    }

    /**
    @notice This function is used to update presale and public sale parameters  
    @dev It can only be called by owner  
    @param _preSaleMintCost Cost to mint one token in presale   
    @param _preSaleStartTime Time when presale starts  
    @param _preSaleDuration Duration for which presale is live  
    @param _maxTokenPerMintPreSale Maximum No of token can be purchased by user in single tx in pre sale  
    @param _limitSupplyInPreSale Pre Sale supply limit  
    @param _publicSaleMintCost Cost to mint one token in pubic sale  
    @param _publicSaleBufferDuration Buffer time to add between presale and public sale i.e 30 + something...  
    @param _publicSaleDuration Duration for which public sales is live  
    @param _maxTokenPerMintPublicSale Maximum No of token can be purchased by user in single tx in public sale  
    @param _maxTokenPerPersonPublicSale Maximum No of token can be purchased by user as whole in public sale  
    */
    function updatePreSale(
        uint256 _preSaleMintCost,
        uint256 _preSaleStartTime,
        uint256 _preSaleDuration,
        uint256 _maxTokenPerMintPreSale,
        uint256 _limitSupplyInPreSale,
        uint256 _publicSaleMintCost,
        uint256 _publicSaleBufferDuration,
        uint256 _publicSaleDuration,
        uint256 _maxTokenPerMintPublicSale,
        uint256 _maxTokenPerPersonPublicSale
    ) external onlyOwner {
        require(
            either(
                both(block.timestamp < preSaleStartTime, _preSaleStartTime > block.timestamp),
                preSaleStartTime == _preSaleStartTime
            ),
            "Invalid Start Time"
        );

        require(block.timestamp < preSaleEndTime, "presale is ended");

        require(
            both(
                _limitSupplyInPreSale > totalMint - publicSaleAirdropCount,
                _limitSupplyInPreSale <= maxSupply - publicSaleAirdropCount
            ),
            "incorrect presale limit supply"
        );

        require(both(_preSaleMintCost > 100, _publicSaleMintCost > 100), "Token cost> 100 wei");
        require(both(_preSaleDuration > 0, _publicSaleDuration > 0), "sale duration>0");
        require(
            both(_maxTokenPerMintPreSale > 0, _maxTokenPerMintPreSale <= _limitSupplyInPreSale),
            "Invalid maximum token per mint in presale"
        );

        require(_maxTokenPerMintPublicSale > 0, "Maximum token per mint in public sale > 0");

        require(
            both(_maxTokenPerPersonPublicSale <= maxSupply, _maxTokenPerPersonPublicSale >= _maxTokenPerMintPublicSale),
            "Invalid Max Token minted per person in public sale"
        );

        preSaleMintCost = _preSaleMintCost;
        publicSaleMintCost = _publicSaleMintCost;

        maxTokenPerMintPreSale = _maxTokenPerMintPreSale;
        limitSupplyInPreSale = _limitSupplyInPreSale;

        preSaleStartTime = _preSaleStartTime;
        unchecked {
            preSaleEndTime = _preSaleStartTime + _preSaleDuration;

            publicSaleBufferDuration = _publicSaleBufferDuration;
            publicSaleStartTime = preSaleEndTime + defaultPublicSaleBufferDuration + _publicSaleBufferDuration;
            publicSaleEndTime = publicSaleStartTime + _publicSaleDuration;
        }
        maxTokenPerMintPublicSale = _maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _maxTokenPerPersonPublicSale;
    }

    /**
    @notice This function is used to update public sale parameters  
    @dev It can only be called by owner  
    @param _publicSaleMintCost Cost to mint one token in pubic sale  
    @param _publicSaleBufferDuration Buffer time to add between presale and public sale i.e 30 + something...  
    @param _publicSaleDuration Duration for which public sales is live  
    @param _maxTokenPerMintPublicSale Maximum No of token can be purchased by user in single tx in public sale  
    @param _maxTokenPerPersonPublicSale Maximum No of token can be purchased by user as whole in public sale  
    */
    function updatePublicSale(
        uint256 _publicSaleMintCost,
        uint256 _publicSaleBufferDuration,
        uint256 _publicSaleDuration,
        uint256 _maxTokenPerMintPublicSale,
        uint256 _maxTokenPerPersonPublicSale
    ) external onlyOwner {
        uint256 _publicSaleStartTime = preSaleEndTime + defaultPublicSaleBufferDuration + _publicSaleBufferDuration;
        require(
            either(
                both(block.timestamp < publicSaleStartTime, _publicSaleStartTime > block.timestamp),
                publicSaleStartTime == _publicSaleStartTime
            ),
            "Invalid Start Time"
        );
        require(block.timestamp < publicSaleEndTime, "Public sale is ended");
        require(_publicSaleMintCost > 100, "Invalid Token cost");
        require(_publicSaleDuration > 0, "Public sale duration > 0");
        require(
            both(
                _maxTokenPerMintPublicSale > 0,
                both(
                    _maxTokenPerPersonPublicSale <= maxSupply,
                    _maxTokenPerPersonPublicSale >= _maxTokenPerMintPublicSale
                )
            ),
            "Maximum token minted per person/per mint not correct"
        );

        publicSaleMintCost = _publicSaleMintCost;
        publicSaleBufferDuration = _publicSaleBufferDuration;
        publicSaleStartTime = _publicSaleStartTime;
        publicSaleEndTime = publicSaleStartTime + _publicSaleDuration;
        maxTokenPerMintPublicSale = _maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _maxTokenPerPersonPublicSale;
    }

    /**
    @notice This function is used to buy and mint nft in presale  
    @dev Random token id is generated for assigned to buyer  
    @param tokenSignQuantity The token quantity that whitelisted buyer can mint  
    @param tokenQuantity The token quantity that whitelisted buyer wants to mint  
    @param signature The signature sent by the buyer  
    */
    function preSaleBuy(
        uint256 tokenSignQuantity,
        uint256 tokenQuantity,
        bytes memory signature
    ) external payable isApproved {
        require(isPreSaleLive(), "presale is not live");

        bytes32 hash = hashforPresale(msg.sender, tokenSignQuantity);

        require(matchAddressSigner(hash, signature), "invalid-signature");

        verifyTokenQtyInPresale(tokenQuantity);

        unchecked{
        require(tokenSignQuantity != 0, "TokenSignQuantity > 0");
        require(
            presalerListPurchases[msg.sender] + tokenQuantity <= tokenSignQuantity,
            "exceeds maximum allowed limit"
        );

        require((preSaleMintCost * tokenQuantity) <= msg.value, "insufficient Amount paid");
        }

        _mintTo(msg.sender, tokenQuantity);

        unchecked {
            presalerListPurchases[msg.sender] += tokenQuantity;
        }
    }

    /**
    @notice This function is used to buy and mint nft in public sale  
    @param tokenQuantity The token quantity that buyer wants to mint  
    */
    function publicSaleBuy(uint256 tokenQuantity) public payable preSaleEnded {
        _publicSaleMint(tokenQuantity);
    }

    /**
    @notice This function is used to buy and mint nft in presale   
    @dev Random token id is generated for assigned to buyer  
    @param tokenSignQuantity The token quantity that whitelisted buyer can mint   
    @param tokenQuantity The token quantity that whitelisted buyer wants to mint   
    @param affiliatedUser The affiliated user address  
    @param commission The commission percentage that will be paid to affiliated user   
    @param signature The signature sent by the buyer   
    */
    function preSaleBuyAffiliated(
        uint256 tokenSignQuantity,
        uint256 tokenQuantity,
        address affiliatedUser,
        uint256 commission,
        bytes memory signature
    ) external payable isApproved {
        require(isPreSaleLive(), "presale is not live");
        require(affiliatedUser != address(0), "Invalid Affiliated user");

        bytes32 hash = hashforPresaleAffiliated(msg.sender, tokenSignQuantity, affiliatedUser, commission);

        require(matchAddressSigner(hash, signature), "invalid-signature");

        verifyTokenQtyInPresale(tokenQuantity);

        unchecked{

        require(tokenSignQuantity != 0, "TokenSignQuantity > 0");
        require(
            presalerListPurchases[msg.sender] + tokenQuantity <= tokenSignQuantity,
            "exceeds maximum allowed limit"
        );

        require((preSaleMintCost * tokenQuantity) <= msg.value, "insufficient amount paid");
        }

        _mintTo(msg.sender, tokenQuantity);

        unchecked {
            totalMintReferral += tokenQuantity;
            presalerListPurchases[msg.sender] += tokenQuantity;
            uint256 receivedAmount = ((preSaleMintCost * commission) * tokenQuantity) / 100;
            affiliatedUserBalance[affiliatedUser] += receivedAmount;
            affiliatedWei += receivedAmount;
        }
    }

    /**
    @notice This function is used to buy and mint nft in public sale for affiliation feature  
    @param tokenQuantity The token quantity that buyer wants to mint  
    @param affiliatedUser The affiliated user address  
    @param commission The commission percentage that will be paid to affiliated user  
    @param signature The signature sent by the buyer  
    */
    function publicSaleBuyAffiliated(
        uint256 tokenQuantity,
        address affiliatedUser,
        uint256 commission,
        bytes memory signature
    ) public payable preSaleEnded {
        require(affiliatedUser != address(0), "Invalid address");
        _publicSaleMintAffiliated(tokenQuantity, affiliatedUser, commission, signature);
    }

    /**
    @notice This function is used to perform Airdrop operation  
    @dev This function is called by only owner when presale and public sales are not live 
    @param list a list to addresses which will get airdrop  
    @param shares an array of presale and public sale shares 
    */
    function _initiateAirdrop(address[] calldata list, uint256[2] calldata shares) internal isSaleOff {
        if (isPreSaleStarted()) {
            require(shares[0] == 0, "Airdrop: Invalid Presale Share");
        }

        require(shares[0] + preSaleAirdropCount <= limitSupplyInPreSale, "Airdrop: Presale share not in range");

        _createAirdrop(list, shares);

        unchecked {
            preSaleAirdropCount += shares[0];
            publicSaleAirdropCount += shares[1];
        }
    }

    /**
    @dev This function is used to verify the token quantity entered by buyer 
    @param _tokenQuantity token quantity entered by the buyer 
    */
    function verifyTokenQtyInPresale(uint256 _tokenQuantity) private view {
        require(both(_tokenQuantity > 0, _tokenQuantity <= maxTokenPerMintPreSale), "Invalid Token Quantity");
        unchecked{
        require(
            _tokenQuantity + totalMint <= limitSupplyInPreSale + publicSaleAirdropCount,
            "exceeding presale supply"
        );
        }
    }

    // ============================ Getter Functions ============================

    /**
    @notice This function is used to check if pre sale is started  
    @return bool Return true if presale is started or not  
    */
    function isPreSaleLive() public view returns (bool) {
        return both(block.timestamp >= preSaleStartTime, block.timestamp <= preSaleEndTime);
    }

    /**
    @notice This function is used to check whether the presale has already started or happened  
    */
    function isPreSaleStarted() private view returns (bool) {
        return block.timestamp >= preSaleStartTime;
    }

    /**
    @notice This function is used in modifier to check whether any sale is running or not (reduces code size)  
    */
    function _isSaleOff() internal view {
        require(
            both(
                either(block.timestamp < publicSaleStartTime, block.timestamp > publicSaleEndTime),
                either(block.timestamp < preSaleStartTime, block.timestamp > preSaleEndTime)
            ),
            "Airdrop:Invalid Time"
        );
    }

    /**
    @notice This function is used in modifier to check whether presale is ended or not (reduces code size)  
    */
    function _onlyWhenPresaleEnded() internal view {
        require(block.timestamp > preSaleEndTime, "the pre-sale is not yet ended");
    }
}