// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

contract Econ721Enumerable {
    // Mapping owner address to token count
    // NFT contract address => owner => count
    mapping(address => mapping(address => uint256)) internal _balances;

    // Mapping from token ID to owner address
    // NFT contract address => tokenId => owner
    mapping(address => mapping(uint256 => address)) internal _owners;

    // Mapping from owner to list of owned token IDs
    // NFT contract address => owner => index => tokenId
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    // NFT contract address => tokenId => index
    mapping(address => mapping(uint256 => uint256)) internal _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    // NFT contract address => tokenIds
    mapping(address => uint256[]) internal _allTokens;

    // Mapping from token id to position in the allTokens array
    // NFT contract address => tokenId => allTokens Index
    mapping(address => mapping(uint256 => uint256)) internal _allTokensIndex;

    function getBalances(address _contractAddress) external view returns (uint256) {
        return _allTokens[_contractAddress].length;
    }

    function balanceOf(address _contractAddress, address _owner) external view returns (uint256) {
        return _balances[_contractAddress][_owner];
    }

    function ownerOf(address _contractAddress, uint256 _tokenId) external view returns (address) {
        address owner = _owners[_contractAddress][_tokenId];
        require(owner != address(0), "Error: owner query for nonexistent token");
        return owner;
    }

    function tokenIdsOfOwner(address _contractAddress, address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = _balances[_contractAddress][_owner];

        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory tokenIds = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                tokenIds[i] = _ownedTokens[_contractAddress][_owner][i];
            }
            return tokenIds;
        }
    }

    function _addTokenToOwnerEnumeration(
        address _contractAddress,
        address _to,
        uint256 _tokenId
    ) internal {
        uint256 length = _balances[_contractAddress][_to];
        _ownedTokens[_contractAddress][_to][length] = _tokenId;
        _ownedTokensIndex[_contractAddress][_tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(address _contractAddress, uint256 _tokenId) internal {
        _allTokensIndex[_contractAddress][_tokenId] = _allTokens[_contractAddress].length;
        _allTokens[_contractAddress].push(_tokenId);
    }

    function _removeTokenFromOwnerEnumeration(
        address _contractAddress,
        address _from,
        uint256 _tokenId
    ) internal {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _balances[_contractAddress][_from] - 1;
        uint256 tokenIndex = _ownedTokensIndex[_contractAddress][_tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[_contractAddress][_from][lastTokenIndex];

            _ownedTokens[_contractAddress][_from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[_contractAddress][lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[_contractAddress][_tokenId];
        delete _ownedTokens[_contractAddress][_from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(address _contractAddress, uint256 _tokenId) internal {
        uint256 lastTokenIndex = _allTokens[_contractAddress].length - 1;
        uint256 tokenIndex = _allTokensIndex[_contractAddress][_tokenId];

        uint256 lastTokenId = _allTokens[_contractAddress][lastTokenIndex];

        _allTokens[_contractAddress][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[_contractAddress][lastTokenId] = tokenIndex; // Update the moved token's index

        delete _allTokensIndex[_contractAddress][_tokenId];
        _allTokens[_contractAddress].pop();
    }
}