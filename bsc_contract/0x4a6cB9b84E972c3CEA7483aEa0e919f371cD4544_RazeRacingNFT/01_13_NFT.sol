// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
contract RazeRacingNFT is ERC1155, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private baseURI = 'ipfs://QmbHVKhtNSBU8xXGmrVQtWosYpbZbiCAqvjCNZpYm8yhdF';
    string public name ='Raze Racing cars';

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public onlyRole(MINTER_ROLE)
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }
    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }



    constructor()
        ERC1155('')
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function setBaseURI(string memory _newBaseuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI=_newBaseuri;
    }

    function uri(
        uint256 _id
    ) public override virtual view returns (string memory) {
        return string(abi.encodePacked( baseURI,"/",
        Strings.toString(_id),".json")
        );
    }
    function setName(string memory _name) public onlyRole(DEFAULT_ADMIN_ROLE)  {
        name = _name;
    }
}