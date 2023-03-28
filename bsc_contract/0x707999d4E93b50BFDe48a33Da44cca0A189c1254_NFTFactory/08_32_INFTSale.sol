// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface INFTSale {
    function setDropFee(uint256 _fee, address _wallet) external;

    function dropFee() external view returns(uint256);

    function feeReceiver() external view returns(address);

    function setDropApproval() external;

    function isDropApproved() external view returns(uint256);
}