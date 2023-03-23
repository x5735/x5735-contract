pragma solidity 0.8.17;

interface IRoyaltyDistribution {
    function globalRoyaltyEnabled() external returns(bool);
    function royaltyDistributionEnabled() external returns(bool);
    function defaultCollaboratorsRoyaltyShare() external returns(RoyaltyShare[] memory);


    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );

    function getDefaultRoyaltyDistribution() external view returns(RoyaltyShare[] memory);

    function getTokenRoyaltyDistribution(uint256 tokenId) external view returns(RoyaltyShare[] memory);

}

struct RoyaltyShare {
    address collaborator;
    uint256 share;
}