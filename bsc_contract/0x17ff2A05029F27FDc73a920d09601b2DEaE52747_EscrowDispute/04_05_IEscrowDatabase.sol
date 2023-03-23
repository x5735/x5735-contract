// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

interface IEscrowDatabase {
    function escrowCounter() external view returns(uint256);

    function increaseEscrowCounter() external;

    function addAllEscrowContracts(address _allContractAddress) external;

    function addGoodsEscrowContracts(address _goodsContractAddress) external;

    function addEscrowsOfUser(address _address, address _escrowContractAddress) external;

    function deleteFromEscrowsOfUser(address _address, address _escrowContractAddress) external;

    function addServicesEscrowContracts(address _servicesContractAddress) external;

    function addNftEscrowContracts(address _nftContractAddress) external;

    function addSourceCodeEscrowContracts(address _sourceCodeContractAddress) external;

    function addGamblingEscrowContracts(address _gamblingContractAddress) external;
    
    function getAllEscrowContracts() external view returns(address[] memory);

    function getGoodsEscrowContracts() external view returns (address[] memory);

    function getServicesEscrowContracts() external view returns (address[] memory);

    function getNftEscrowContracts() external view returns (address[] memory);

    function getSourceCodeEscrowContracts() external view returns (address[] memory);

    function getGamblingEscrowContracts() external view returns (address[] memory);
}