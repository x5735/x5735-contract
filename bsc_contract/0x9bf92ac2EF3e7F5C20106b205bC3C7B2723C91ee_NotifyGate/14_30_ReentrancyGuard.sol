// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.10;

error ReentrancyGuard__Locked();

abstract contract ReentrancyGuard {
    uint256 private __locked;

    modifier nonReentrant() {
        __nonReentrantBefore();
        _;
        __nonReentrantAfter();
    }

    constructor() payable {
        assembly {
            sstore(__locked.slot, 1)
        }
    }

    function __nonReentrantBefore() private {
        assembly {
            if eq(sload(__locked.slot), 2) {
                mstore(0x00, 0xc0d27a97)
                revert(0x1c, 0x04)
            }
            sstore(__locked.slot, 2)
        }
    }

    function __nonReentrantAfter() private {
        assembly {
            sstore(__locked.slot, 1)
        }
    }
}