// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract BaseNFT is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using Strings for uint256;

    /** @notice Name of the collection */
    string public name;

    /** @notice Symbol of the collection */
    string public symbol;

    /** @notice baseUri of the metadata of collection */
    string public baseUri;

    /**  @notice total mint count of collection */
    uint256 public totalMint;

    /**  @notice current token id of collection */
    uint256 internal currentTokenId;

    /**
    @notice Time at which public sale starts, 
    * preSaleStartTime + preSaleDuration + publicSaleBufferDuration  
    */
    uint256 public publicSaleStartTime;

    /** @notice Time at which public sale end (i.e., publicSaleStartTime + publicSaleDuration)
     */
    uint256 public publicSaleEndTime;

    /** @notice Max supply of collection */
    uint256 public maxSupply;

    /**
    @notice This function is used to get the token id uri  
    @param _tokenId The token id for which uri is required  
    @return string The uri of the token  
    */
    function uri(uint256 _tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseUri, Strings.toString(_tokenId)));
    }

    /**
    @dev This function is used to inrement without checking the overflow condition - save gas  
    @param i increment it  
    @return uint256 inremented value  
    */
    function unchecked_inc(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }

    /**
    @dev Fuctions to increment token id without checking the overflow condition - save gas 
    */
    function _incrementTokenId() internal {
        unchecked {
            ++currentTokenId;
        }
    }

    /**
    @dev Fuctions to perform OR and AND operations - save gas a bit 
    */
    function either(bool x, bool y) internal pure returns (bool z) {
        z = x || y;
    }

    function both(bool x, bool y) internal pure returns (bool z) {
        z = x && y;
    }
}