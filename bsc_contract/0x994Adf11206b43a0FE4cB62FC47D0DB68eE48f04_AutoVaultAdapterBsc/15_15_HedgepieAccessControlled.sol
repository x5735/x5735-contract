// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "../interfaces/IHedgepieAuthority.sol";

abstract contract HedgepieAccessControlled {
    /* ========== EVENTS ========== */

    event AuthorityUpdated(IHedgepieAuthority indexed authority);

    string UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    string PAUSED = "PAUSED"; // save gas

    /* ========== STATE VARIABLES ========== */

    IHedgepieAuthority public authority;

    /* ========== Constructor ========== */

    constructor(IHedgepieAuthority _authority) {
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }

    /* ========== MODIFIERS ========== */

    modifier whenNotPaused() {
        require(!authority.paused(), PAUSED);
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == authority.governor(), UNAUTHORIZED);
        _;
    }

    modifier onlyPathManager() {
        require(msg.sender == authority.pathManager(), UNAUTHORIZED);
        _;
    }

    modifier onlyAdapterManager() {
        require(msg.sender == authority.adapterManager(), UNAUTHORIZED);
        _;
    }

    modifier onlyInvestor() {
        require(msg.sender == authority.hInvestor(), UNAUTHORIZED);
        _;
    }

    /* ========== GOV ONLY ========== */

    function setAuthority(
        IHedgepieAuthority _newAuthority
    ) external onlyGovernor {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }
}