// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UsdtToken is Ownable, ERC20("USDT Token", "USDT") {

    uint256 private _maxSupply = 10000000000 * 10 ** 18;
    mapping (address => bool) private _roler;
    mapping (address => bool) private _minter;

    constructor() public  {
        _roler[_msgSender()] = true;
        _minter[_msgSender()] = true;
    }

    modifier onlyRoler() {
        require(_roler[_msgSender()], "Not permission");
        _;
    }

    modifier onlyMinter() {
        require(_minter[_msgSender()], "Not permission");
        _;
    }
    
    function mint(address to, uint256 amount) public onlyMinter {
        require(totalSupply() + amount <= _maxSupply, "Over maxTotalSupply");
        _mint(to, amount);
    } 

    function maxTotalSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function setRoler(address addr, bool state) public onlyRoler {
        _roler[addr] = state;
    }

    function setMinter(address minter, bool state) public onlyRoler {
        _minter[minter] = state;
    }
}