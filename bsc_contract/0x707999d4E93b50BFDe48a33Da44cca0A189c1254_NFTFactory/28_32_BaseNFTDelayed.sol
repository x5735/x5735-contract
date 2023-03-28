// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract BaseNFTDelayed {
    /// @notice Boolean to check if NFTs are revealed
    bool public revealed;

    /**
    @notice Event when token are revealed  
    @param time Time when token are revealed  
    */
    event TokensRevealed(uint256 time);

    /**
    @notice This function is used to reveal the token can only be called by owner  
    @dev TokensRevealed and URI event is emitted  
    */
    function _revealTokens() internal {
        require(!revealed, "Already revealed");
        revealed = true;
        emit TokensRevealed(block.timestamp);
    }
}