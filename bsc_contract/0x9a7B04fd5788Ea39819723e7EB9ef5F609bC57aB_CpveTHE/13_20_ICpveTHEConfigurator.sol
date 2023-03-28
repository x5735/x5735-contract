// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import "../interfaces/ISolidlyRouter.sol";

interface ICpveTHEConfigurator {
    struct Gauges {
        address bribeGauge;
        address feeGauge;
        address[] bribeTokens;
        address[] feeTokens;
    }

    function redeemFeePercent() external view returns (uint256);
    function minDuringTimeWithdraw() external view returns (uint256);
    function isAutoIncreaseLock() external view returns (bool);
    function maxPeg() external view returns (uint256);
    function reserveRate() external view returns (uint256);

    function hasSellingTax(address _from, address _to) external view returns (uint256);
    function hasBuyingTax(address _from, address _to) external view returns (uint256);
    function deadWallet() external view returns (address);
    function getFee() external view returns (uint256);
    function coFeeRecipient() external view returns (address); 
    function lpInitialized(address _lp) external view returns (bool);
    
    function getGauges(address _lp) external view returns (Gauges memory);
    function solidVoter() external view returns (address);
    function ve() external view returns (address);
    function want() external view returns (address);
    function veDist() external view returns (address);
    function router() external view returns (address);
    function getRoutes(address _token) external view returns (ISolidlyRouter.Routes[] memory);
}