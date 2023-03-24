// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../libraries/BotanStruct.sol";

interface IBotanNFT is IERC721Upgradeable {
    function getPlantDataByUser(uint256 _tokenId) external view returns (BotanStruct.Botan memory);

    function getPlantDataByLogic(uint256 _tokenId) external view returns (BotanStruct.Botan memory);

    function mintSeedOrPlantByLogic(
        address _owner,
        BotanStruct.Botan calldata _plantData,
        uint256 _tx,
        bool _safe
    ) external returns (uint256);

    function breedByLogic(
        address _owner,
        uint256 _dadId,
        uint256 _momId,
        BotanStruct.BotanRarity _rarity,
        uint64 _blocks,
        uint256 _tx,
        bool _safe
    ) external returns (uint256);

    function growByLogic(
        uint256 _tokenId,
        BotanStruct.Botan calldata _newGeneData,
        uint256 _tx
    ) external returns (BotanStruct.Botan memory);

    function exists(uint256 tokenId) external view returns (bool);

    function burnByCXO(uint256 _tokenId) external;

    function burnByLogic(uint256 _tokenId) external;
}