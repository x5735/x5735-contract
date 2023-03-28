// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract GenesisFee is OwnableUpgradeable {
    uint public baseFee;
    uint public partnerFeePercentage;
    uint public constant MAX_BASE_FEE = 100_000;
    uint public constant MAX_PARTNER_FEE_PERCENTAGE = 1_000_000;

    event BaseFeeUpdated(uint baseFee);
    event PartnerFeePercentageUpdated(uint partnerFeePercentage);

    function setBaseFee(uint _baseFee) public onlyOwner {
        _setBaseFee(_baseFee);
    }

    function _setBaseFee(uint _baseFee) internal {
        require(_baseFee <= MAX_BASE_FEE, "Fee can't be greater than 10%");

        baseFee = _baseFee;

        emit BaseFeeUpdated(_baseFee);
    }

    function setPartnerFeePercentage(uint _partnerFeePercentage) public virtual onlyOwner {
        _setPartnerFeePercentage(_partnerFeePercentage);
    }

    function _setPartnerFeePercentage(uint _partnerFeePercentage) internal {
        require(
            _partnerFeePercentage <= MAX_PARTNER_FEE_PERCENTAGE,
            "Percentage can't be greater than 100%"
        );

        partnerFeePercentage = _partnerFeePercentage;

        emit PartnerFeePercentageUpdated(_partnerFeePercentage);
    }
}