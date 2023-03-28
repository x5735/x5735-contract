// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./BaseNFT.sol";

abstract contract BaseNFTAirdrop is BaseNFT {
    uint256 public preSaleAirdropCount;

    uint256 public publicSaleAirdropCount;

    /**
    @notice This function is used to create Airdrop  
    @dev It can only be called by owner  
    @param list list of addresses  
    @param shares an array of preSaleShare and PublicSaleShare in Airdrop   
    */
    function _createAirdrop(address[] calldata list, uint256[2] calldata shares) internal {
        uint256 dropSupply = list.length;
        unchecked {
            require(both(dropSupply != 0, dropSupply == (shares[0] + shares[1])), "Airdrop: Mismatch-Input");

            require(dropSupply + totalMint <= maxSupply, "Airdrop: exceeds max Supply");

            for (uint256 i; i < dropSupply; i = unchecked_inc(i)) {
                require(list[i] != address(0), "Invalid recipient");

                _getNextToken();

                totalMint = unchecked_inc(totalMint);

                _mint(list[i], currentTokenId, 1, "0x");
            }
        }
    }

    /** 
    @dev This function is used to get next valid token ID to mint  
    */
    function _getNextToken() internal {
        require(both(totalMint <= maxSupply, currentTokenId < maxSupply), "All Values assigned");

        _incrementTokenId();
    }
}