// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/interfaces/IBasePositionManager.sol";
import "../core/VaultMSData.sol";
import "hardhat/console.sol";

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

contract VaultReader {
    using SafeMath for uint256;

    function getVaultTokenInfoV4(address _vault, address _positionManager, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 15;

        IVault vault = IVault(_vault);
        // console.log(address(vault));
        IVaultUtils vaultUtils = IVaultUtils(IVaultTarget(_vault).vaultUtils());
        // console.log(address(vaultUtils));
        IVaultPriceFeedV2 priceFeed = IVaultPriceFeedV2(vault.priceFeed());
        IBasePositionManager positionManager = IBasePositionManager(_positionManager);

        console.log(address(vaultUtils));

        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                token = _weth;
            }
            VaultMSData.TokenBase memory tBase = vault.getTokenBase(token);

            uint256 gUSDtk = vault.usdToTokenMin(token, vault.guaranteedUsd(token));
            amounts[i * propsLength] = tBase.poolAmount;//_vault> gUSDtk ? tBase.poolAmount.sub(gUSDtk) : 0;
            amounts[i * propsLength + 1] = tBase.reservedAmount;
            amounts[i * propsLength + 2] = vault.usdxAmounts(token);
            amounts[i * propsLength + 3] = vault.getRedemptionAmount(token, _usdxAmount);
            amounts[i * propsLength + 4] = tBase.weight;
            amounts[i * propsLength + 5] = tBase.bufferAmount;
            amounts[i * propsLength + 6] = tBase.maxUSDAmounts;
            amounts[i * propsLength + 7] = vaultUtils.maxGlobalShortSizes(token);
            // console.log(31);
            amounts[i * propsLength + 8] = positionManager.maxGlobalShortSizes(token);
            amounts[i * propsLength + 9] = positionManager.maxGlobalLongSizes(token);
            // console.log(41);
            amounts[i * propsLength + 10] = vault.getMinPrice(token);
            amounts[i * propsLength + 11] = vault.getMaxPrice(token);
            amounts[i * propsLength + 12] = vaultUtils.maxGlobalLongSizes(token);
            // (amounts[i * propsLength + 13], ) = priceFeed.getPrimaryPrice(token, false);
            // (amounts[i * propsLength + 14], ) = priceFeed.getPrimaryPrice(token, true);
            amounts[i * propsLength + 13] = priceFeed.getPrice(token, false, true, false);
            amounts[i * propsLength + 14] = priceFeed.getPrice(token, true, true, false);
        }

        return amounts;
    }
    
    function getVaultTokenProfit(address _vault, bool maximise, address[] memory _tokens) public view returns (TokenProfit[] memory) {
        IVault vault = IVault(_vault);

        TokenProfit[] memory _tPf = new TokenProfit[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _tPf[i].token = _tokens[i];
            VaultMSData.TradingRec memory tradingRec = vault.getTradingRec(_tPf[i].token);
            uint256 price = maximise ? vault.getMaxPrice(_tPf[i].token) : vault.getMinPrice(_tPf[i].token);

            _tPf[i].shortSize = tradingRec.shortSize;
            if (_tPf[i].shortSize > 0){
                _tPf[i].aveShortPrice = tradingRec.shortAveragePrice;
                uint256 priceDelta = _tPf[i].aveShortPrice > price ? _tPf[i].aveShortPrice.sub(price) : price.sub(_tPf[i].aveShortPrice);
                uint256 delta = _tPf[i].shortSize.mul(priceDelta).div(_tPf[i].aveShortPrice);
                if (price > _tPf[i].aveShortPrice) {
                    _tPf[i].shortProfit = int256(delta);
                } else {
                    _tPf[i].shortProfit = -int256(delta);
                }    
            }

            _tPf[i].longSize = tradingRec.longSize;
            if (_tPf[i].longSize > 0){
                _tPf[i].aveLongPrice = tradingRec.longAveragePrice;
                uint256 priceDelta = _tPf[i].aveLongPrice > price ? _tPf[i].aveLongPrice.sub(price) : price.sub(_tPf[i].aveLongPrice);
                uint256 delta = _tPf[i].longSize.mul(priceDelta).div(_tPf[i].aveLongPrice);
                if (price < _tPf[i].aveLongPrice) {
                    _tPf[i].longProfit = int256(delta);
                } else {
                    _tPf[i].longProfit = -int256(delta);
                }    
            }
        }
        return _tPf;
    }
    
    function getPoolTokenInfo(address _vault, address _token) public view returns (uint256[] memory) {
        IVault vault = IVault(_vault);
        require(vault.isFundingToken(_token), "invalid token");
        uint256[] memory tokenIinfo = new uint256[](7);        
        // tokenIinfo[0] = vault.totalTokenWeights() > 0 ? vault.tokenWeights(_token).mul(1000000).div(vault.totalTokenWeights()) : 0;
        // tokenIinfo[1] = vault.tokenUtilization(_token); 
        // tokenIinfo[2] = IERC20(_token).balanceOf(_vault).add(vault.feeSold(_token)).sub(vault.feeReserves(_token));
        // tokenIinfo[3] = vault.getMaxPrice(_token);
        // tokenIinfo[4] = vault.getMinPrice(_token);
        // tokenIinfo[5] = vault.cumulativeFundingRates(_token);
        // tokenIinfo[6] = vault.poolAmounts(_token);
        return tokenIinfo;
    }




}