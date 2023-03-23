pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC2981.sol";



abstract contract RoyaltyDistribution is Ownable, IERC2981{

    struct RoyaltyShare {
        address collaborator;
        uint256 share;
    }

    bool public globalRoyaltyEnabled = true;

    // if royaltyDistributionEnabled == (false) - all royalties go to royaltyReceiver
    // if royaltyDistributionEnabled == (true) - all royalties
    // are divided between collaborators according to specified shares and rest goes to royaltyReceiver
    // Royalties distribution is not supported by IERC2981 standard and will only work on Decrypt marketplace
    bool public royaltyDistributionEnabled = true;

    //royalty percent in basis points (1000 = 10%)
    uint256 public globalRoyalty;
    //personal token royalty amount - in basis points.
    mapping(uint256 => uint256) public tokenRoyalty;

    //List of collaborators, who will receive the share of royalty. Empty by default
    RoyaltyShare[] private defaultCollaboratorsRoyaltyShare;
    //tokenId => royalty distribution for this token
    mapping(uint256 => RoyaltyShare[]) private tokenCollaboratorsRoyaltyShare;

    address public royaltyReceiver;

    event NewGlobalRoyalty(uint256);
    event NewTokenRoyalty(uint256 royalty, uint256 tokenId);
    event NewRoyaltyReceiver(address);


    /*
    * Params
    * uint256 _tokenId - the NFT asset queried for royalty information
    * uint256 _salePrice - the sale price of the NFT asset specified by _tokenId
    *
    * Called with the sale price by marketplace to determine the amount of royalty
    * needed to be paid to a wallet for specific tokenId.
    */
    function royaltyInfo
    (
        uint256 _tokenId,
        uint256 _salePrice
    )
    external
    view
    override
    returns (
        address receiver,
        uint256 royaltyAmount
    ){
        uint256 royaltyAmount;
        if(globalRoyaltyEnabled){
            if(tokenRoyalty[_tokenId] == 0){
                royaltyAmount = _salePrice * globalRoyalty / 10000;
            }else{
                royaltyAmount = _salePrice * tokenRoyalty[_tokenId] / 10000;
            }
        }else{
            royaltyAmount = 0;
        }
        return (royaltyReceiver, royaltyAmount);
    }


    /*
     * Params
     * address newRoyaltyReceiver - address of wallet/contract who will receive royalty by default
     *
     * Sets new address of royalty receiver.
     * If royalty distributes among collaborators,
     * this address will receive the rest of the royalty after substraction
     */
    function setRoyaltyReceiver (address newRoyaltyReceiver) external onlyOwner {
        require(newRoyaltyReceiver != address(0), 'Cant set 0 address');
        require(newRoyaltyReceiver != royaltyReceiver, 'This address is already a receiver');
        royaltyReceiver = newRoyaltyReceiver;

        emit NewRoyaltyReceiver(newRoyaltyReceiver);
    }


    /*
     * Params
     * uint256 _royalty - Royalty amount in basis points (10% = 1000)
     *
     * Sets default royalty amount
     * This amount will be sent to royalty receiver or/and distributed among collaborators
     */
    function setGlobalRoyalty (uint256 _royalty) external onlyOwner {
        require(_royalty <= 9000,'Royalty is over 90%');
        globalRoyalty = _royalty;

        emit NewGlobalRoyalty(_royalty);
    }


    /*
     * Params
     * uint256 _royalty - Royalty amount in basis points (10% = 1000)
     *
     * Sets individual token royalty amount
     * If it's 0 - global royalty amount will be used instead
     * This amount will be sent to royalty receiver or/and distributed among collaborators
     */
    function setTokenRoyalty (uint256 _royalty, uint256 _tokenId) external onlyOwner {
        require(_royalty <= 9000,'Royalty is over 90%');
        tokenRoyalty[_tokenId] = _royalty;

        emit NewTokenRoyalty(_royalty, _tokenId);
    }


    /*
     * Disables any royalty for all NFT contract
     */
    function disableRoyalty() external onlyOwner {
        globalRoyaltyEnabled = false;
    }


    /*
     * Enables royalty for all NFT contract
     */
    function enableRoyalty() external onlyOwner {
        globalRoyaltyEnabled = true;
    }


    /*
     * Disables distribution of any royalty. All royalties go straight to royaltyReceiver
     */
    function disableRoyaltyDistribution() external onlyOwner {
        royaltyDistributionEnabled = false;
    }


    /*
     * Disables distribution of any royalty. All royalties go straight to royaltyReceiver
     */
    function enableRoyaltyDistribution() external onlyOwner {
        royaltyDistributionEnabled = true;
    }


    /*
     * Params
     * address[] calldata collaborators - array of addresses to receive royalty share
     * uint256[] calldata shares - array of shares in basis points  for collaborators (basis points).
     * Example: 1000 = 10% of royalty
     *
     * Function sets default royalty distribution
     * Royalty distribution is not supported by IERC2981 standard and will only work on Decrypt marketplace
     */
    function setDefaultRoyaltyDistribution(
        address[] calldata collaborators,
        uint256[] calldata shares
    ) external onlyOwner {
        require(collaborators.length == shares.length, 'Arrays dont match');

        uint256 totalShares = 0;
        for (uint i=0; i<shares.length; i++){
            totalShares += shares[i];
        }
        require(totalShares <= 10000, 'Total shares > 10000');


        delete defaultCollaboratorsRoyaltyShare;
        for (uint i=0; i<collaborators.length; i++){
            defaultCollaboratorsRoyaltyShare.push(RoyaltyShare({
            collaborator: collaborators[i],
            share: shares[i]
            }));
        }
    }


    /*
     * Function returns array of default royalties distribution
     * Royalties distribution is not supported by IERC2981 standard and will only work on Decrypt marketplace
     */
    function getDefaultRoyaltyDistribution()
    public
    view
    returns(RoyaltyShare[] memory)
    {
        return defaultCollaboratorsRoyaltyShare;
    }


    /*
     * Params
     * address[] calldata collaborators - array of addresses to receive royalty share
     * uint256[] calldata shares - array of shares in basis points  for collaborators (basis points).
     * Example: 1000 = 10% of royalty
     * uint256 tokenId - Token index ID
     *
     * Function sets default royalty distribution
     * Royalty distribution is not supported by IERC2981 standard and will only work on Decrypt marketplace
     */
    function setTokenRoyaltyDistribution(
        address[] calldata collaborators,
        uint256[] calldata shares,
        uint256 tokenId
    ) external onlyOwner {
        require(collaborators.length == shares.length, 'Arrays dont match');

        uint256 totalShares = 0;
        for (uint i=0; i<shares.length; i++){
            totalShares += shares[i];
        }
        require(totalShares <= 10000, 'Total shares > 10000');


        delete tokenCollaboratorsRoyaltyShare[tokenId];

        for (uint i=0; i<collaborators.length; i++){
            tokenCollaboratorsRoyaltyShare[tokenId].push(RoyaltyShare({
            collaborator: collaborators[i],
            share: shares[i]
            }));
        }
    }


    /*
     * Params
     * uint256 tokenId - ID index of token
     *
     * Function returns array of royalties distribution specified for this token
     * If it's empty, default royalty distribution will be used instead
     * Royalties distribution is not supported by IERC2981 standard and will only work on Decrypt marketplace
     */
    function getTokenRoyaltyDistribution(uint256 tokenId)
    public
    view
    returns(RoyaltyShare[] memory)
    {
        return tokenCollaboratorsRoyaltyShare[tokenId];
    }

}