// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpaceAnimalOre is ERC20, ERC20Burnable, Pausable, Ownable {
    address public signatory;

    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);
    event OwnerMint(address account, uint256 amount);
    event OwnerBurn(address account, uint256 amount);

    constructor(address _signatory, uint256 _initialMint) ERC20("Space Animals Ore", "SAOre") {
        signatory = _signatory;
        mint(msg.sender, _initialMint);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(
        address _account,
        uint256 _amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        require(msg.sender == _account, "not account address");
        require(permit(_account, _amount, deadline, v, r, s), "permit not allowed");

        _mint(msg.sender, _amount);
        emit Mint(msg.sender, _amount);
    }

    function burn(
        address _account,
        uint256 _amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        require(msg.sender == _account, "not account address");
        require(permit(_account, _amount, deadline, v, r, s), "permit not allowed");

        _burn(msg.sender, _amount);
        emit Burn(msg.sender, _amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        emit OwnerMint(to, amount);
    }

    function burn(address to, uint256 amount) public onlyOwner {
        _burn(to, amount);
        emit OwnerBurn(to, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20) {
        super._mint(account, amount);
    }

    function permit(
        address _account,
        uint256 _amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {
        bytes32 domainSeparator = keccak256(abi.encode(keccak256("EIP712Domain(string name)"), keccak256(bytes("Space Animals"))));

        bytes32 structHash = keccak256(abi.encode(keccak256("Permit(address account,uint256 amount,uint256 deadline)"), _account, _amount, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address _signatory = ecrecover(digest, v, r, s);

        if (_signatory == address(0) || signatory != _signatory || block.timestamp > deadline) {
            return false;
        }

        return true;
    }
}