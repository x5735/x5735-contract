// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "./GenesisFactory.sol";
import "./GenesisBond_v2.sol";
import "./abstract/GenesisFee.sol";

contract GenesisFactory_v2 is GenesisFactory, GenesisFee {
    struct BondParamsInitializeBond {
        uint controlVariable;
        uint vestingTerm;
        uint minimumPrice;
        uint maxPayout;
        uint maxDebt;
        uint maxTotalPayout;
        uint initialDebt;
    }

    function initialize_v2(
        address _bondImplementationV2,
        uint _baseFee,
        uint _partnerFeePercentage
    ) public onlyOwner reinitializer(2) {
        require(_bondImplementationV2 != address(0), "Invalid bond implementation address");

        setBondImplementation(_bondImplementationV2);
        _setBaseFee(_baseFee);
        _setPartnerFeePercentage(_partnerFeePercentage);
    }

    function deploy(
        BondParams calldata,
        BondNftParams calldata,
        TreasuryParams calldata
    ) public pure override {
        revert("DEPRECATED");
    }

    function deploy(
        address _partner,
        BondParams calldata _bondParams,
        BondParamsInitializeBond calldata _bondParamsInitializeBond,
        BondNftParams calldata _bondNftParams,
        TreasuryParams calldata _treasuryParams
    ) external returns (BondInfo memory deployedBondInfo) {
        require(_getInitializedVersion() == 2, "Pending initialization");

        uint bondId = bondCount[msg.sender];

        super.deploy(_bondParams, _bondNftParams, _treasuryParams);

        deployedBondInfo = bondInfo[msg.sender][bondId];

        GenesisBond_v2 bond = GenesisBond_v2(deployedBondInfo.bond);

        bond.initializeBond(
            _bondParamsInitializeBond.controlVariable,
            _bondParamsInitializeBond.vestingTerm,
            _bondParamsInitializeBond.minimumPrice,
            _bondParamsInitializeBond.maxPayout,
            _bondParamsInitializeBond.maxDebt,
            _bondParamsInitializeBond.maxTotalPayout,
            _bondParamsInitializeBond.initialDebt
        );

        bond.initialize_v2(_partner, baseFee, partnerFeePercentage);
    }
}