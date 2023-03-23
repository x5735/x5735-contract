// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EscrowDatabase is Ownable {
    uint256 public escrowCounter = 0;
    address[] private _factoriesContracts;
    address[] private _allEscrowContracts;
    address[] private _goodsEscrowContracts;
    address[] private _servicesEscrowContracts;
    address[] private _nftEscrowContracts;
    address[] private _sourceCodeContracts;
    address[] private _gamblingContracts;
    mapping(address => address[]) private _escrowsOfUser;

    fallback() external payable {}

    receive() external payable {}

    modifier onlyFactoriesContracts() {
        bool _found = false;

        for (uint256 i = 0; i < _factoriesContracts.length; i++) {
            if (_factoriesContracts[i] == msg.sender) {
                _found = true;
            }
        }

        require(_found, "The call is only available from the factory smart contract");
        _;
    }

    modifier factoriesAndAllContracts() {
        bool _foundInFactoriesContracts = false;
        bool _foundInAllContracts = false;

        for (uint256 i = 0; i < _factoriesContracts.length; i++) {
            if (_factoriesContracts[i] == msg.sender) {
                _foundInFactoriesContracts = true;
            }
        }

        for (uint256 i = 0; i < _allEscrowContracts.length; i++) {
            if (_allEscrowContracts[i] == msg.sender) {
                _foundInAllContracts = true;
            }
        }

        require(_foundInFactoriesContracts || _foundInAllContracts, "The call is only available from the factory or escrow smart contract");
        _;
    }

    function increaseEscrowCounter() public onlyFactoriesContracts {
        escrowCounter += 1;
    }

    function addFactoriesContracts(address _factoryAddress) public onlyOwner {
        _factoriesContracts.push(_factoryAddress);
    }

    function addAllEscrowContracts(address _allContractAddress) public onlyFactoriesContracts {
        _allEscrowContracts.push(_allContractAddress);
    }

    function addGoodsEscrowContracts(address _goodsContractAddress) public onlyFactoriesContracts {
        _goodsEscrowContracts.push(_goodsContractAddress);
    }

    function addServicesEscrowContracts(address _servicesContractAddress) public onlyFactoriesContracts {
        _servicesEscrowContracts.push(_servicesContractAddress);
    }

    function addNftEscrowContracts(address _nftContractAddress) public onlyFactoriesContracts {
        _nftEscrowContracts.push(_nftContractAddress);
    }

    function addSourceCodeEscrowContracts(address _sourceCodeContractAddress) public onlyFactoriesContracts {
        _sourceCodeContracts.push(_sourceCodeContractAddress);
    }

    function addGamblingEscrowContracts(address _gamblingContractAddress) public onlyFactoriesContracts {
        _gamblingContracts.push(_gamblingContractAddress);
    }

    function addEscrowsOfUser(address _address, address _escrowContractAddress) public factoriesAndAllContracts {
        _escrowsOfUser[_address].push(_escrowContractAddress);
    }

    function deleteFromEscrowsOfUser(address _address, address _escrowContractAddress) public factoriesAndAllContracts {
        for (uint256 i = 0; i < _escrowsOfUser[_address].length; i++) {
            if (_escrowsOfUser[_address][i] == _escrowContractAddress) {
                _escrowsOfUser[_address][i] = _escrowsOfUser[_address][_escrowsOfUser[_address].length - 1];
                _escrowsOfUser[_address].pop();
            }
        }
    }

    function getEscrowAddressById(uint256 _id) public view returns (address) {
        return _allEscrowContracts[_id - 1];
    }

    function getFactoriesContracts() public onlyOwner view returns (address[] memory) {
        return _factoriesContracts;
    }

    function getAllEscrowContracts() public view returns (address[] memory) {
        return _allEscrowContracts;
    }

    function getGoodsEscrowContracts() public view returns (address[] memory) {
        return _goodsEscrowContracts;
    }

    function getServicesEscrowContracts() public view returns (address[] memory) {
        return _servicesEscrowContracts;
    }

    function getNftEscrowContracts() public view returns (address[] memory) {
        return _nftEscrowContracts;
    }

    function getSourceCodeEscrowContracts() public view returns (address[] memory) {
        return _sourceCodeContracts;
    }

    function getGamblingEscrowContracts() public view returns (address[] memory) {
        return _gamblingContracts;
    }

    function getEscrowsOfUserByAddress(address _address) public view returns (address[] memory) {
        return _escrowsOfUser[_address];
    }
}