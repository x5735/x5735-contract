// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/Context.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract LlamaLandRelic is Context, ERC1155URIStorage, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant ADD_AMOUNT_ROLE = keccak256("ADD_AMOUNT_ROLE");

    address public owner;
    address public admin;
    uint public serialNo;

    event Upgrade(uint tokenId, string cid);

    constructor(address _owner, address _admin) ERC1155("ipfs://") {
        _setBaseURI("ipfs://");

        owner = _owner;
        admin = _admin;

        _grantRole(OWNER_ROLE, owner);
        _grantRole(ADMIN_ROLE, admin);

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(MINT_ROLE, ADMIN_ROLE);
        _setRoleAdmin(UPGRADE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BURN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADD_AMOUNT_ROLE, ADMIN_ROLE);
    }

    function mint(address to, string memory cid, uint32 amount)
    onlyRole(MINT_ROLE)
    external {
        _setURI(serialNo, cid);
        _mint(to, serialNo, amount, "");
        serialNo++;
    }

    function addAmount(address to, uint tokenId, uint32 amount)
    onlyRole(ADD_AMOUNT_ROLE)
    external {
        require(tokenId < serialNo, "Token ID is nonexistent");
        _mint(to, tokenId, amount, "");
    }

    function upgrade(uint tokenId, string memory cid)
    onlyRole(UPGRADE_ROLE)
    external {
        _setURI(tokenId, cid);
        emit Upgrade(tokenId, cid);
    }

    function burn(address from, uint tokenId, uint32 amount)
    onlyRole(BURN_ROLE)
    external {
        _burn(from, tokenId, amount);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}