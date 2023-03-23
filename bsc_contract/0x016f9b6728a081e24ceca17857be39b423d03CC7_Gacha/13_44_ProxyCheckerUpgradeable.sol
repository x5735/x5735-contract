// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Revert error if call is made from a proxy contract
 */
error ProxyChecker__EOAUnallowed();

/**
 * @dev Revert error if call is made from an externally owned account
 */
error ProxyChecker__ProxyUnallowed();

/**
 * @title ProxyCheckerUpgradeable
 * @dev Abstract contract for checking if a call was made by a proxy contract or an externally owned account.
 */
abstract contract ProxyCheckerUpgradeable {
    modifier onlyEOA() {
        _onlyEOA(msg.sender);
        _;
    }

    function _onlyEOA(address sender_) internal view {
        _onlyEOA(sender_, _txOrigin());
    }

    function _onlyEOA(address msgSender_, address txOrigin_) internal pure {
        if (_isProxyCall(msgSender_, txOrigin_))
            revert ProxyChecker__ProxyUnallowed();
    }

    function _onlyProxy(address sender_) internal view {
        if (!(_isProxyCall(sender_, _txOrigin()) || _isProxy(sender_)))
            revert ProxyChecker__EOAUnallowed();
    }

    function _onlyProxy(address msgSender_, address txOrigin_) internal view {
        if (!(_isProxyCall(msgSender_, txOrigin_) || _isProxy(msgSender_)))
            revert ProxyChecker__EOAUnallowed();
    }

    function _isProxyCall(
        address msgSender_,
        address txOrigin_
    ) internal pure returns (bool) {
        return msgSender_ != txOrigin_;
    }

    function _isProxy(address caller_) internal view returns (bool) {
        return caller_.code.length != 0;
    }

    function _txOrigin() internal view returns (address) {
        return tx.origin;
    }

    uint256[50] private _gap;
}