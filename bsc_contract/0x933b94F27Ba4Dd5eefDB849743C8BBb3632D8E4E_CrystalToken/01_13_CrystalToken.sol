// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CrystalToken is ERC20, ERC20Burnable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

    modifier gameMasterOnly() {
        _isGameMaster();
        _;
    }

    constructor() ERC20("Crystal Token", "CRYSTAL") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_MASTER, msg.sender);
    }

    function _isGameMaster() private view {
        require(hasRole(GAME_MASTER, msg.sender), "E1002");
    }

    function mint(address to, uint256 amount) public gameMasterOnly {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        if (
            hasRole(GAME_MASTER, msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            _burn(account, amount);
        } else {
            super.burnFrom(account, amount);
        }
    }

    function transfer(
        address to,
        uint256 amount
    ) public override gameMasterOnly returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override gameMasterOnly returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}