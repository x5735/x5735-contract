// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IGenesisBondNFT is IERC721Enumerable {
    function addMinter(
        address minter
    ) external;

    function mint(
        address to,
        address bondAddress
    ) external returns (uint256);
}