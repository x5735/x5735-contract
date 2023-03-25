// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SafeMath.sol";

contract FreedomFinanceToken is ERC20, Ownable {
     using SafeMath for uint256;

    constructor() ERC20("Freedom Finance", "FDO") {}

    uint8 public transferPercent;
    
    struct Percent {
        uint8 inPercent; 
        uint8 outPercent;
    }

    mapping(address => Percent) public contractPercentMap;

    mapping(address => bool) public contractMap;

    mapping(address => bool) public transferWhiteListMap;
    mapping(address => mapping( address => bool)) public contractWhiteListMap;

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setTransferPercent(uint8 percent) public onlyOwner {
        require(percent >= 0, 'percent cannot less than 0');
        require(percent <= 100, 'percent cannot more than 100');

        transferPercent = percent;
    }

    function setContractPercent(address addr, uint8 inPercent, uint8 outPercent) public onlyOwner {
        require(inPercent >= 0 && outPercent >= 0, 'percent cannot less than 0');
        require(inPercent <= 100 && outPercent <= 100, 'percent cannot more than 100');
        contractPercentMap[addr] = Percent({
            inPercent: inPercent,
            outPercent: outPercent
        });
        contractMap[addr] = true;
    }

    function setTransferWhite(address addr, bool isWhite) public onlyOwner {
        transferWhiteListMap[addr] = isWhite;
    }

    function setContractWhite(address caddr, address addr, bool isWhite) public onlyOwner {
        contractWhiteListMap[caddr][addr] = isWhite;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();

        uint256 fromBalance = balanceOf(owner);
        require(fromBalance >= amount, "transfer amount exceeds balance");

        bool isToContract = contractMap[to];
        bool isFromContract = contractMap[owner];
        if (isToContract) {
            uint fee = 0;
            uint realAmount = amount;
            if (!contractWhiteListMap[to][owner]) {
                fee = amount.mul(contractPercentMap[to].inPercent).div(100);
                realAmount = amount - fee;
                _burn(owner, fee);
            }
            _transfer(owner, to, realAmount);
        } else if (isFromContract) {
            uint fee = 0;
            uint realAmount = amount;
            if (!contractWhiteListMap[owner][to]) {
                fee = amount.mul(contractPercentMap[owner].outPercent).div(100);
                realAmount = amount - fee;
                _burn(owner, fee);
            }
            _transfer(owner, to, realAmount);
        } else {
            uint fee = 0;
            uint realAmount = amount;
            if (!transferWhiteListMap[owner]) {
                fee = amount.mul(transferPercent).div(100);
                realAmount = amount - fee;
                _burn(owner, fee);
            }
            _transfer(owner, to, realAmount);
        }
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "transfer amount exceeds balance");

        bool isToContract = contractMap[to];
        bool isFromContract = contractMap[from];

        if (isToContract) {
            uint fee = 0;
            uint realAmount = amount;
            if (!contractWhiteListMap[to][from]) {
                fee = amount.mul(contractPercentMap[to].inPercent).div(100);
                realAmount = amount - fee;
                _burn(from, fee);
            }
            _transfer(from, to, realAmount);
        } else if (isFromContract) {
            uint fee = 0;
            uint realAmount = amount;
            if (!contractWhiteListMap[from][to]) {
                fee = amount.mul(contractPercentMap[from].outPercent).div(100);
                realAmount = amount - fee;
                _burn(from, fee);
            }
            _transfer(from, to, realAmount);
        } else {
            uint fee = 0;
            uint realAmount = amount;
            if (!transferWhiteListMap[from]) {
                fee = amount.mul(transferPercent).div(100);
                realAmount = amount - fee;
                _burn(from, fee);
            }
            _transfer(from, to, realAmount);
        }

        return true;
    }
}