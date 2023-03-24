// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../utils/Admin.sol";

abstract contract RouterStorage is Admin {
    address public implementation;

    bool internal _mutex;

    modifier _reentryLock_() {
        require(!_mutex, "Router: reentry");
        _mutex = true;
        _;
        _mutex = false;
    }

    // executor => active
    mapping(address => bool) public isExecutor;

    struct RequestTrade {
        uint256 index;
        uint256 timestamp;
        address account;
        address pool;
        string symbolName;
        int256 tradeVolume;
        address asset;
        int256 amount;
        int256 priceLimit;
        uint256 executionFee;
    }

    struct OracleSignature {
        bytes32 oracleSymbolId;
        uint256 timestamp;
        uint256 value;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    // index => requestTrade
    mapping(uint256 => RequestTrade) public requestTrades;

    uint256 public tradeIndex;
    uint256 public lastExecutedIndex;
    uint256 public maxDelayTime;
    uint256 public executionFee;
    uint256 public unclaimedFee;

    struct RequestTradeNew {
        uint256 index;
        uint256 timestamp;
        address pool;
        address account;
        address asset;
        int256 amount;
        string symbolName;
        uint256 executionFee;
        int256[] tradeParams;
    }



    mapping (uint256 => RequestTradeNew) public requestTradesNew;
}