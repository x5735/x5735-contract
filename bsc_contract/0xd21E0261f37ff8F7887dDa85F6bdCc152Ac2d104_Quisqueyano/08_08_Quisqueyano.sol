// SPDX-License-Identifier: Apache-2.0


/* @author
* ¨€¨€¨[       ¨€¨€¨€¨€¨€¨[  ¨€¨€¨[   ¨€¨€¨[ ¨€¨€¨€¨[   ¨€¨€¨[  ¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨[  ¨€¨€¨[ ¨€¨€¨[ ¨€¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨[
* ¨€¨€¨U      ¨€¨€¨X¨T¨T¨€¨€¨[ ¨€¨€¨U   ¨€¨€¨U ¨€¨€¨€¨€¨[  ¨€¨€¨U ¨€¨€¨X¨T¨T¨T¨T¨a ¨€¨€¨U  ¨€¨€¨U ¨€¨€¨U ¨€¨€¨X¨T¨T¨T¨T¨a ¨€¨€¨U
* ¨€¨€¨U      ¨€¨€¨€¨€¨€¨€¨€¨U ¨€¨€¨U   ¨€¨€¨U ¨€¨€¨X¨€¨€¨[ ¨€¨€¨U ¨€¨€¨U      ¨€¨€¨€¨€¨€¨€¨€¨U ¨€¨€¨U ¨€¨€¨€¨€¨€¨[   ¨€¨€¨U
* ¨€¨€¨U      ¨€¨€¨X¨T¨T¨€¨€¨U ¨€¨€¨U   ¨€¨€¨U ¨€¨€¨U¨^¨€¨€¨[¨€¨€¨U ¨€¨€¨U      ¨€¨€¨X¨T¨T¨€¨€¨U ¨€¨€¨U ¨€¨€¨X¨T¨T¨a   ¨€¨€¨U
* ¨€¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨U  ¨€¨€¨U ¨^¨€¨€¨€¨€¨€¨€¨X¨a ¨€¨€¨U ¨^¨€¨€¨€¨€¨U ¨^¨€¨€¨€¨€¨€¨€¨[ ¨€¨€¨U  ¨€¨€¨U ¨€¨€¨U ¨€¨€¨U      ¨€¨€¨U
* ¨^¨T¨T¨T¨T¨T¨T¨a ¨^¨T¨a  ¨^¨T¨a  ¨^¨T¨T¨T¨T¨T¨a  ¨^¨T¨a  ¨^¨T¨T¨T¨a  ¨^¨T¨T¨T¨T¨T¨a ¨^¨T¨a  ¨^¨T¨a ¨^¨T¨a ¨^¨T¨a      ¨^¨T¨a
*
* @custom: version 1.0.0
*/


pragma solidity >=0.8.13 <0.9.0;

 import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";   
   import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

        import "@openzeppelin/contracts/access/Ownable.sol";

        contract Quisqueyano is ERC20Capped , ERC20Burnable , Ownable {
   
        constructor(uint256 cap) ERC20("Quisqueyano", "QQY") ERC20Capped(cap){

         
         }     

    
    /// @notice Mint function
    /// @dev only the owner can mint
    /// @param to  user Address to mint tokens
    /// @param amount the amount of tokens to mint
    function mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }

        function _mint(address account, uint256 amount) internal virtual override (ERC20, ERC20Capped) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
        } 

/// @dev Returns the number of decimals used to get its user representation 
       /// @return value of 'decimals'
       function decimals() public view virtual override returns (uint8) {
        return 4;
    }

    
   
   

    
  /**
 * @notice Rescue ERC20 tokens locked up in this contract.
 * @param tokenContract ERC20 token contract address
 * @param to Recipient address
 * @param amount Amount to withdraw
 */
function rescueERC20(
    IERC20 tokenContract,
    address to,
    uint256 amount
) external onlyOwner {
    require(to != address(0), "Zero address");
    tokenContract.transfer(to, amount);
}
}