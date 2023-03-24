// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../libraries/LandStruct.sol";

interface ILandNFT is IERC721Upgradeable {
    function getLandDataByLogic(uint256 _tokenId) external view returns (LandStruct.Land memory);

    function getLandDataByUser(uint256 _tokenId) external view returns (LandStruct.Land memory);

    function exists(uint256 tokenId) external view returns (bool);

    function mintLandByLogic(
        address _owner,
        LandStruct.Land calldata _landData,
        uint256 _tx,
        bool _safe
    ) external returns (uint256);

    function burnByCXO(uint256 _tokenId) external;

    function burnByLogic(uint256 _tokenId) external;
}