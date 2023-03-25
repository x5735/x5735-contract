// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ITokenPlugin.sol";
import "../ERC20/ERC20Burnable.sol";

/**
 * @title Token
 * @dev BEP20 compatible token.
 */
contract TokenV2 is Ownable, AccessControl, ERC20Burnable {
    using Address for address;

    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    ITokenPlugin[] public plugins;
    
    uint8 internal _decimals;
    
    event PluginsUpdated();
    
    /**
     * @dev Mints all tokens to deployer
     * @param amount Initial supply
     * @param name Token name.
     * @param symbol Token symbol.
     */
    constructor(uint256 amount, string memory name, string memory symbol, uint8 dec) ERC20(name, symbol) {
        _decimals = dec;
        transferOwnership(msg.sender);
        _setRoleAdmin(MANAGE_ROLE, MANAGE_ROLE);
        _setRoleAdmin(MINTER_ROLE, MANAGE_ROLE);
        _setRoleAdmin(BURNER_ROLE, MANAGE_ROLE);
        _setupRole(MANAGE_ROLE, address(this));
        _mint(_msgSender(), amount);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the address of the current owner.
     *
     * IMPORTANT: This method is required to be able to transfer tokens directly between their Binance Chain
     * and Binance Smart Chain. More on this issue can be found in:
     * https://github.com/binance-chain/BEPs/blob/master/BEP20.md#5116-getowner
     */
    function getOwner() external view returns (address) {
        return owner();
    }
    
    function setMinter(address account, bool status) external virtual onlyOwner returns (bool) {
        bytes4 selector = status ? this.grantRole.selector : this.revokeRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, MINTER_ROLE, account));
        return true;
    }

    function isMinter(address account) external virtual view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function setBurner(address account, bool status) external virtual onlyOwner returns (bool) {
        bytes4 selector = status ? this.grantRole.selector : this.revokeRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, BURNER_ROLE, account));
        return true;
    }

    function isBurner(address account) external virtual view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    /** @dev Creates `amount` tokens and assigns them to msg.sender, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(uint256 amount) external virtual onlyRole(MINTER_ROLE) {
        _mint(_msgSender(), amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `addr`, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `addr` cannot be the zero address.
     */
    function mintFor(address addr, uint256 amount) external virtual onlyRole(MINTER_ROLE) {
        _mint(addr, amount);
    }


    /** @dev Creates `amount` tokens and assigns them to `addr`, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `addr` cannot be the zero address.
     */
    function burnFor(address addr, uint256 amount) external virtual onlyRole(BURNER_ROLE) {
        _burn(addr, amount);
    }
    
    function setPlugins(ITokenPlugin[] memory _plugins) external virtual onlyOwner {
        require(_plugins.length <= 10, 'ERC20: cannot add more than 10 plugins');
        delete plugins;
        for (uint256 i=0; i<_plugins.length; i++) {
            require(address(_plugins[i]) != address(0), 'ERC20: invalid plugin address');
            _approve(address(this), address(_plugins[i]), type(uint256).max);
            plugins.push(_plugins[i]);
        }
        emit PluginsUpdated();
    }

    // ERC20 infinite approve fix
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance == type(uint256).max) {
            _transfer(from, to, amount);
            return true;
        }
        return super.transferFrom(from, to, amount);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        _beforeTokenTransfer(sender, recipient, amount);
        _transferTokens(sender, address(this), amount);
        for (uint256 i=0; i<plugins.length; i++) amount = plugins[i].execute(sender, recipient, amount);
        _transferTokens(address(this), recipient, amount);
        emit Transfer(sender, recipient, amount);
        _afterTokenTransfer(sender, recipient, amount);
    }

    function _transferTokens(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
    }
}