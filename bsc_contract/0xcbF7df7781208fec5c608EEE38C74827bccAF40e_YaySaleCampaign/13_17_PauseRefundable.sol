// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;


contract PauseRefundable {

    bool private _paused;
    bool private _refundable;
    bool private _hasSetRefundableOnce;

    event SetPaused(bool pause);
    event SetRefundable(bool refundable);
    event Refund(address token, uint amount, address to);

    modifier notPaused() {
        require(!_paused, "Paused");
        _;
    }

    modifier canRefund() {
        require(_paused && _refundable, "Cannot refund");
        _;
    }

    function isPausedRefundable() external view returns (bool paused, bool refundable) {
        return (_paused, _refundable);
    }

    function _setPause(bool set) internal {
        // Cannot unpause if has set refundable previously //
        bool notAllowed = _hasSetRefundableOnce && !set;
        require(!notAllowed, "Cannot unpause");
        if (_paused != set) {
            _paused = set;
            emit SetPaused(set);
        }
    }

    function _setRefundable(bool set) internal {
        require(_paused, "Not paused yet");
        if (!_hasSetRefundableOnce && set) {
            _hasSetRefundableOnce = true;
        }

        if (_refundable != set) {
            _refundable = set;
            emit SetRefundable(set);
        }
    }
}