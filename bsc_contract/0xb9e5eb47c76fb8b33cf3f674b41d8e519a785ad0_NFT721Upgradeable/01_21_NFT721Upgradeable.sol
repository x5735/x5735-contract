// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract NFT721Upgradeable is
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Error: Minter role required");
        _;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC721_init(name, symbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function mint(address to, string memory tokenUri) external onlyMinter returns (uint256 id) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenUri);

        return newTokenId;
    }

    function mint(
        address to,
        string memory tokenUri,
        uint256 amount
    ) external onlyMinter returns (uint256[] memory ids) {
        ids = new uint256[](amount);

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();

            uint256 newTokenId = _tokenIds.current();

            _mint(to, newTokenId);
            _setTokenURI(newTokenId, tokenUri);

            ids[i] = newTokenId;
        }
    }

    function burn(uint256[] memory tokenIds) public {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ) {
            _burn(tokenIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    function burn(uint256 fromTokenId, uint256 toTokenId) public {
        for (uint256 tokenId = fromTokenId; tokenId <= toTokenId; ) {
            _burn(tokenId);

            unchecked {
                ++tokenId;
            }
        }
    }

    function tokenIdsOfOwner(address ownerAddress) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(ownerAddress);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                result[i] = tokenOfOwnerByIndex(ownerAddress, i);
            }
            return result;
        }
    }

    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Error: caller is not owner nor approved");
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}