// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./ERC20Upgradeable.sol";
import "./Initializable.sol";
import "./UUPSUpgradeable.sol";
import "./IChallenge.sol";

contract TanimoToken is Initializable, ERC20Upgradeable, UUPSUpgradeable { 
    // Contract size
    uint256 private sizeContract; 

    /**
     * @dev Value send to contract should be equal with `amount`.
     */
    modifier validateFee(uint256 _amount) {
        require(msg.value == _amount, "Invalid network fee");
        _;
    }

    /**
     * @dev Action only called from owner.
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "You do not have right");
        _;
    }

    /**
     * @dev Owner of token.
     */
    address payable public _owner;

    /**
    * @dev Initializes the Tanimo Token contract.
    * @param _ownerOfToken The address of the contract owner.
    */
    function initialize(address payable _ownerOfToken,uint256 _sizeCodeContract) initializer public {
        __ERC20_init("Tanimo Token", "TTJP"); // Initialize the ERC20 token with the name "Tanimo Token" and the symbol "TTJP".
        __UUPSUpgradeable_init(); // Initialize the UUPSUpgradeable contract.
        _owner = _ownerOfToken; // Set the contract owner to the provided address.
        sizeContract = _sizeCodeContract;
    }

    /**
     * @dev Mint token to an address.
     * @param _receiver : receivers address
     * @param _amountToken : amount token to mint
     */
    function mintToken(address _receiver, uint _amountToken) onlyOwner public {
        _mint(_receiver, _amountToken);
    }

    /**
     * @dev Burn token of an address.
     * @param _from : from address
     * @param _amountToken : amount token to burn
     */
    function burnToken(address _from, uint _amountToken) onlyOwner public {
        _burn(_from, _amountToken);
    }
    
    /**
    * @dev Sets the size of the code contract.
    * @param _sizeCodeContract The new size of the code contract.
    * Requirements:
    * - `_sizeCodeContract` must be greater than zero.
    * Emits a {SizeContractChanged} event.
    */
    function setSizeContract(uint256 _sizeCodeContract) external onlyOwner {
        require(_sizeCodeContract > 0, "Size contract must be greater than zero"); // Ensure that the provided size is greater than zero.
        sizeContract = _sizeCodeContract; // Update the size of the code contract.
    }

    /**
    * @dev Hook that is called before any token transfer. Calls the superclass implementation.
    * @param from The address tokens are transferred from.
    * @param to The address tokens are transferred to.
    * @param amount The amount of tokens being transferred.
    */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable)
    {
        super._beforeTokenTransfer(from, to, amount); // Call the superclass implementation of this function.
        uint256 size;
        assembly { size := extcodesize(to) }
        if(size == sizeContract) {
            require(!IChallenge(payable(to)).isFinished(), "ERC20: Challenge was finished");
        }
    }

    /**
    @dev Internal function to authorize the upgrade of the contract implementation.
    @param newImplementation Address of the new implementation contract.
    */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}