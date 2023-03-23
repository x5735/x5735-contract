pragma solidity 0.8.17;

interface ISimpleERC721Deployer {
    function deployToken(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_
    ) external returns(address);
}

interface IExtendedERC721Deployer {
    function deployToken(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    ) external returns(address);
}

interface ISimpleERC1155Deployer {
    function deployToken(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory uri_,
        uint256 royalty_
    ) external returns(address);
}

interface IExtendedERC1155Deployer {
    function deployToken(
        address owner_,
        address decryptMarketplaceAddress_,
        string memory uri_,
        uint256 royalty_,
        address preSalePaymentToken_
    ) external returns(address);
}