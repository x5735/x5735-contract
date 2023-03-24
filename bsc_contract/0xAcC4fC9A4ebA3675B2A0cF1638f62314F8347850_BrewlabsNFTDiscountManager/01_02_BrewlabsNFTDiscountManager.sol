pragma solidity >=0.5.0;

import './interfaces/IBrewlabsNFTCollection.sol';

contract BrewlabsNFTDiscountManager {
    address private admin;

    address private nftCollection; // nft collection address
    mapping (uint8 => uint) private discountAmount;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Brewlabs: permission out');
        _;
    }

    /**
     * @dev update NFT discount amount for each nft rarity level
     * @param _nftRarityLevel nft rarity level
     * @param _amount swap fee discount value for the rarity level
     */
    function updateNFTDiscount(uint8 _nftRarityLevel, uint _amount) external {
        require(nftCollection != address(0), 'Brewlabs: no nft collection set');
        require(_amount > 0, 'Brewlabs: invalid nft discount value');
        discountAmount[_nftRarityLevel] = _amount;
    }

    /**
     * @dev return discount value for specific user
     * it returns discount value for max rarity among the nfts user holding in his wallet
     * @param _to nft holder
     */
    function getNFTDiscount(address _to) internal view returns(uint amount) {
        if (nftCollection != address(0)) {
            uint256[] memory tokenIds = IBrewlabsNFTCollection(nftCollection).tokensOfOwner(_to);
            uint8 maxRarityLevel = 0;
            for (uint i; i < tokenIds.length; i++) {
                uint8 rarityLevel = IBrewlabsNFTCollection(nftCollection).getAttributeRarity(tokenIds[i]);
                if (maxRarityLevel < rarityLevel)
                    maxRarityLevel = rarityLevel;
            }
            amount = discountAmount[maxRarityLevel];
        } else {
            amount = 0;
        }
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setNFTCollection(address _nftCollection) external onlyAdmin {
        nftCollection = _nftCollection;
    }
}