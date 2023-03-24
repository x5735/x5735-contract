// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./HedgepieAccessControlled.sol";
import "../interfaces/IHedgepieAuthority.sol";

contract HedgepieAuthority is IHedgepieAuthority, HedgepieAccessControlled {
    /* ========== STATE VARIABLES ========== */

    address public override governor;

    address public override pathManager;

    address public override adapterManager;

    address public override hInvestor;

    address public override hYBNFT;

    address public override hAdapterList;

    address public override pathFinder;

    address public newGovernor;

    address public newPathManager;

    address public newAdapterManager;

    bool public override paused;

    /* ========== Constructor ========== */

    constructor(
        address _governor,
        address _pathManager,
        address _adapterManager
    ) HedgepieAccessControlled(IHedgepieAuthority(address(this))) {
        governor = _governor;
        emit GovernorPushed(address(0), governor, true);
        pathManager = _pathManager;
        emit PathManagerPushed(address(0), pathManager, true);
        adapterManager = _adapterManager;
        emit AdapterManagerPushed(address(0), adapterManager, true);
    }

    /* ========== GOV ONLY ========== */

    function pushGovernor(
        address _newGovernor,
        bool _effectiveImmediately
    ) external onlyGovernor {
        if (_effectiveImmediately) governor = _newGovernor;
        newGovernor = _newGovernor;
        emit GovernorPushed(governor, newGovernor, _effectiveImmediately);
    }

    function pushPathManager(
        address _newPathManager,
        bool _effectiveImmediately
    ) external onlyGovernor {
        if (_effectiveImmediately) pathManager = _newPathManager;
        newPathManager = _newPathManager;
        emit PathManagerPushed(
            pathManager,
            newPathManager,
            _effectiveImmediately
        );
    }

    function pushAdapterManager(
        address _newAdapterManager,
        bool _effectiveImmediately
    ) external onlyGovernor {
        if (_effectiveImmediately) adapterManager = _newAdapterManager;
        newAdapterManager = _newAdapterManager;
        emit AdapterManagerPushed(
            adapterManager,
            newAdapterManager,
            _effectiveImmediately
        );
    }

    function pause() external onlyGovernor {
        paused = true;
    }

    function unpause() external onlyGovernor {
        paused = false;
    }

    function setHInvestor(address _hInvestor) external onlyGovernor {
        emit HInvestorUpdated(hInvestor, _hInvestor);
        hInvestor = _hInvestor;
    }

    function setHYBNFT(address _hYBNFT) external onlyGovernor {
        emit HYBNFTUpdated(hYBNFT, _hYBNFT);
        hYBNFT = _hYBNFT;
    }

    function setHAdapterList(address _hAdapterList) external onlyGovernor {
        emit HAdapterListUpdated(hAdapterList, _hAdapterList);
        hAdapterList = _hAdapterList;
    }

    function setPathFinder(address _pathFinder) external onlyGovernor {
        emit PathFinderUpdated(pathFinder, _pathFinder);
        pathFinder = _pathFinder;
    }

    /* ========== PENDING ROLE ONLY ========== */

    function pullGovernor() external {
        require(msg.sender == newGovernor, "!newGovernor");
        emit GovernorPulled(governor, newGovernor);
        governor = newGovernor;
    }

    function pullPathManager() external {
        require(msg.sender == newPathManager, "!newGuard");
        emit PathManagerPulled(pathManager, newPathManager);
        pathManager = newPathManager;
    }

    function pullAdapterManager() external {
        require(msg.sender == newAdapterManager, "!newAdapterManager");
        emit AdapterManagerPulled(adapterManager, newAdapterManager);
        adapterManager = newAdapterManager;
    }
}