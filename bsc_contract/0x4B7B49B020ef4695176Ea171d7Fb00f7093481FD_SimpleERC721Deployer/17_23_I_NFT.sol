pragma solidity 0.8.17;

interface ICreator {
    function deployedTokenContract(address) external view returns(bool);
}

interface ILazyMint721 {
    function exists(uint256 tokenId) external view returns (bool);
    function owner() external view returns (address);
    function lazyMint(address to, uint256 tokenId) external;
}

interface ILazyMint1155 {
    function owner() external view returns (address);
    function lazyMint(address to, uint256 tokenId, uint256 amount) external;
}

interface IPreSale721 {
    function getTokenInfo (address buyer, uint256 tokenId, uint256 eventId)
        external view returns (uint256 tokenPrice, address paymentToken, bool availableForBuyer);
    function countTokensBought(uint256 eventId, address buyer) external;
}

interface IPreSale1155 {
    function getTokenInfo(address buyer, uint256 tokenId, uint256 quantity, uint256 eventId)
        external view returns (uint256 tokenPrice, address paymentToken, bool availableForBuyer);
    function countTokensBought(address buyer, uint256 tokenId, uint256 amount, uint256 eventId) external;
}

interface CustomToken {
    function forbidToTradeOnOtherMarketplaces(bool _forbidden) external;
}