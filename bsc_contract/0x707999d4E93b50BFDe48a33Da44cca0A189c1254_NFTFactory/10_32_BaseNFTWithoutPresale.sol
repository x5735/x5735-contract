// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Base/BaseNFTSale.sol";
import "./BaseNFTAirdrop.sol";

contract BaseNFTWithoutPresale is BaseNFTSale, BaseNFTAirdrop {
    struct publicSaleConfig {
        uint256 _publicSaleMintCost;
        uint256 _publicSaleStartTime;
        uint256 _publicSaleDuration;
        uint256 _maxTokenPerMintPublicSale;
        uint256 _maxTokenPerPersonPublicSale;
    }

    modifier isSaleOff() {
        _isSaleOff();
        _;
    }

    /**
    @notice This function is used to update public sale parameters  
    @dev It can only be called by owner  
    @param _publicSaleMintCost Cost to mint one token in pubic sale  
    @param _publicSaleStartTime Buffer time to add between presale and public sale i.e 30 + something...  
    @param _publicSaleDuration Duration for which public sales is live  
    @param _maxTokenPerMintPublicSale Maximum No of tokens that can be purchased by user in single tx in public sale  
    @param _maxTokenPerPersonPublicSale Maximum No of token can be purchased by user as whole in public sale  
    */
    function updatePublicSale(
        uint256 _publicSaleMintCost,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleDuration,
        uint256 _maxTokenPerMintPublicSale,
        uint256 _maxTokenPerPersonPublicSale
    ) external onlyOwner {
        require(
            either(
                both(block.timestamp < publicSaleStartTime, _publicSaleStartTime > block.timestamp),
                publicSaleStartTime == _publicSaleStartTime
            ),
            "Invalid Start Time"
        );
        require(block.timestamp < publicSaleEndTime, "The public sale is ended cannot update");
        require(_publicSaleMintCost > 100, "Invalid Token cost");
        require(_publicSaleDuration > 0, "Public sale duration>0");
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
        publicSaleStartTime = _publicSaleStartTime;
        publicSaleEndTime = publicSaleStartTime + _publicSaleDuration;
        maxTokenPerMintPublicSale = _maxTokenPerMintPublicSale;
        maxTokenPerPersonPublicSale = _maxTokenPerPersonPublicSale;
    }

    /**
    @notice This function is used to buy and mint nft in public sale  
    @param tokenQuantity The token quantity that buyer wants to mint  
    */
    function publicSaleBuy(uint256 tokenQuantity) external payable {
        _publicSaleMint(tokenQuantity);
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
    ) external payable {
        _publicSaleMintAffiliated(tokenQuantity, affiliatedUser, commission, signature);
    }

    /**
    @notice This function is used to give away NFTs 
    @dev This function is called when the public sale is not live 
    @param list a list to addresses which will get airdrop  
    @param shares an array of presale and public sale shares (shares[0] should always be zero in without presale case) 
    */
    function _initiateAirdrop(address[] calldata list, uint256[2] calldata shares) internal isSaleOff {
        require(shares[0] == 0, "Airdrop:Invalid shares");

        _createAirdrop(list, shares);
    }

    /**
    @notice This function is used in modifier to check whether any sale is running or not (reduces code size)  
    */
    function _isSaleOff() internal view {
        require(
            either(block.timestamp < publicSaleStartTime, block.timestamp > publicSaleEndTime),
            "Airdrop:Invalid Time"
        );
    }
}