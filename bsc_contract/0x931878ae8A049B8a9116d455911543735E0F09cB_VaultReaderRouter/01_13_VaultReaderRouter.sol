// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/interfaces/IBasePositionManager.sol";
import "../core/VaultMSData.sol";


interface IVaultTarget {
    function vaultUtils() external view returns (address);
}


struct TokenProfit{
    address token;
    //tokenBase part
    int256 longProfit;
    uint256 aveLongPrice;
    uint256 longSize;

    int256 shortProfit;
    uint256 aveShortPrice;
    uint256 shortSize;
}

interface VaultReaderIntf{
    function getVaultTokenInfoV4(address _vault, address _positionManager, address _weth, uint256 _usdxAmount, address[] memory _tokens) external view returns (uint256[] memory);
    function getVaultTokenProfit(address _vault, bool maximise, address[] memory _tokens) external view returns (TokenProfit[] memory);
    function getPoolTokenInfo(address _vault, address _token) external view returns (uint256[] memory);
}
contract VaultReaderRouter is Ownable{

    mapping(address => bool) public isOldVersion;
    address public preV_vaultReader;
    address public newV_vaultReader;

    function setOldVersion(address _vault, bool _status) external onlyOwner{
        isOldVersion[_vault] = _status;
    }

    function setVaultReader(address _pre_v, address _new_v) external onlyOwner{
        preV_vaultReader = _pre_v;
        newV_vaultReader = _new_v;
    }

    function getVaultTokenInfoV4(address _vault, address _positionManager, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        if (isOldVersion[_vault])
            return VaultReaderIntf(preV_vaultReader).getVaultTokenInfoV4(_vault,  _positionManager,  _weth,  _usdxAmount, _tokens);
        else
            return VaultReaderIntf(newV_vaultReader).getVaultTokenInfoV4(_vault,  _positionManager,  _weth,  _usdxAmount, _tokens);
    }
    
    function getVaultTokenProfit(address _vault, bool maximise, address[] memory _tokens) public view returns (TokenProfit[] memory) {
        if (isOldVersion[_vault])
            return VaultReaderIntf(preV_vaultReader).getVaultTokenProfit(_vault,  maximise, _tokens);
        else
            return VaultReaderIntf(newV_vaultReader).getVaultTokenProfit(_vault,  maximise, _tokens);
    }
    
    function getPoolTokenInfo(address _vault, address _token) public view returns (uint256[] memory) {
        if (isOldVersion[_vault])
            return VaultReaderIntf(preV_vaultReader).getPoolTokenInfo(_vault,  _token);
        else
            return VaultReaderIntf(newV_vaultReader).getPoolTokenInfo(_vault,  _token);
    }




}