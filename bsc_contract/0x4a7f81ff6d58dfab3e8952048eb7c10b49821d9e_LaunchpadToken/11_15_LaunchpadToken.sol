// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../Token/IERC20Delegated.sol";
import "../Token/Extension/TransferFirewall.sol";

/**
 * @title LaunchpadToken
 * @dev BEP20 compatible token.
 */
contract LaunchpadToken is ERC20, IERC20Delegated, Ownable, AccessControl, TransferFirewall {
    using Address for address;

    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Mints all tokens to deployer
     * @param amount Initial supply
     * @param name Token name.
     * @param symbol Token symbol.
     */
    constructor(uint256 amount, string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(_msgSender(), amount);

        transferOwnership(_msgSender());

        _setRoleAdmin(MANAGE_ROLE, MANAGE_ROLE);
        _setRoleAdmin(MINTER_ROLE, MANAGE_ROLE);
        _setRoleAdmin(BURNER_ROLE, MANAGE_ROLE);

        _setupRole(MANAGE_ROLE, address(this));
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

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function addMinter(address account) external virtual onlyOwner returns (bool) {
        bytes4 selector = this.grantRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, MINTER_ROLE, account));
        return true;
    }

    function delMinter(address account) external virtual onlyOwner returns (bool) {
        bytes4 selector = this.revokeRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, MINTER_ROLE, account));
        return true;
    }

    function isMinter(address account) external virtual view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function addBurner(address account) external virtual onlyOwner returns (bool) {
        bytes4 selector = this.grantRole.selector;
        address(this).functionCall(abi.encodeWithSelector(selector, BURNER_ROLE, account));
        return true;
    }

    function delBurner(address account) external virtual onlyOwner returns (bool) {
        bytes4 selector = this.revokeRole.selector;
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
    function mint(uint256 amount) external virtual override onlyRole(MINTER_ROLE) {
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
    function mintFor(address addr, uint256 amount) external virtual override onlyRole(MINTER_ROLE) {
        _mint(addr, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to msg.sender, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function burn(uint256 amount) external virtual override onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `addr`, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `addr` cannot be the zero address.
     */
    function burnFor(address addr, uint256 amount) external virtual override onlyRole(BURNER_ROLE) {
        _burn(addr, amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override onlyWhitelisted(sender, recipient) {
        super._transfer(sender, recipient, amount);
    }
}