// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IFSPFactory {

    function totalDepositAmount(address account) external returns (uint256);
    function RFXAddress() external returns (address);
    function platformOwner() external returns (address);

    function getDepositFee(bool _isReflection) external view returns (uint256);
    function getEarlyWithdrawFee(bool _isReflection) external view returns (uint256);
    function getCanceledWithdrawFee(bool _isReflection) external view returns (uint256);
    function getRewardClaimFee(bool _isReflection) external view returns (uint256);
    function getReflectionFee() external view returns (uint256);

    function updateTotalDepositAmount(address _user, uint256 _amount, bool _type) external;
    function updateTokenDepositAmount(address _tokenAddress, address _user, uint256 _amount, bool _type) external;

    function isPlatformOwner(address _admin) external view returns (bool);

}