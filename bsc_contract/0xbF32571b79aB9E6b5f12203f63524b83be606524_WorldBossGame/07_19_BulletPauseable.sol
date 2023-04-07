// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "./OwnableUpgradeable.sol";

abstract contract BulletPauseable is OwnableUpgradeable {
    event BulletPaused(address account);
    event BulletUnpaused(address account);
    bool public isBulletPausing;

    modifier whenBulletNotPaused() {
        require(!isBulletPausing, "Pausable: paused");
        _;
    }

    function setBulletPause(bool pause_) external onlyAdmin {
        require(isBulletPausing != pause_);
        isBulletPausing = pause_;
        if (isBulletPausing) {
            emit BulletPaused(address(this));
        } else {
            emit BulletUnpaused(address(this));
        }
    }
}