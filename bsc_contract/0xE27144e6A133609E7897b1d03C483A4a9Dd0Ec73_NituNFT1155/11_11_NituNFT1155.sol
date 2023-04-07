// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NituNFT1155 is ERC1155, Ownable, ERC1155Supply {
    uint256 public constant TOKEN_ID = 1;

    address public CONTRACT_MINING_POOL = address(0);
    address public ADMIN_ADDRESS = 0x5f2192f495af8e4A102059379f46C596906690F2;

    constructor() ERC1155("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setMiningPool(address _address) public onlyOwner {
        CONTRACT_MINING_POOL = _address;
    }

    function setAdminAddress(address _address) public onlyOwner {
        ADMIN_ADDRESS = _address;
    }

    function mint(uint256 amount, bytes memory data) public onlyOwner {
        _mint(ADMIN_ADDRESS, TOKEN_ID, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}