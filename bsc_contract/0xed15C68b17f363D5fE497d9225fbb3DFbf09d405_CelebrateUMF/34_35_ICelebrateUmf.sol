// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol';

interface ICelebrateUmf is IERC721EnumerableUpgradeable {
    function contractURI() external view returns (string memory);

    function setBaseURI(string memory baseURI_) external;

    function baseURI() external view returns (string memory);

    function batchMint(address[] memory toList) external;

    function batchMintToAddress(address to, uint256 quantity) external;

    function batchTransferFrom(address to, uint256[] memory tokenIdList) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);
}