// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IPool.sol";
import "./IBroker.sol";
import "../oracle/IOracleManager.sol";
import "../utils/Admin.sol";
import "./RouterStorage.sol";
import "../library/SafeMath.sol";
import "../library/SafeERC20.sol";
import {ISymbolComplement} from "./BrokerImplementation.sol";

contract RouterImplementation is RouterStorage {
    using SafeMath for int256;

    using SafeMath for uint256;

    using SafeERC20 for IERC20;

    IBroker public immutable broker;

    IOracleManager public immutable oracleManager;

    event SetExecutor(address executor, bool isActive);

    event ErrorString(uint256 indexed index, string message);

    event LowLevelString(uint256 indexed index, bytes data);

    event TradeWithMargin(
        address indexed user,
        address indexed pool,
        address asset,
        int256 amount,
        string symbolName,
        int256 tradeVolume,
        int256 priceLimit,
        address client
    );

    event CreateRequestTrade(
        uint256 indexed index,
        uint256 indexed timestamp,
        address indexed account,
        string[] symbolNames
    );

    event ExecuteTrade(
        uint256 indexed index,
        uint256 indexed timestamp,
        address indexed account
    );

    event CancelTrade(
        uint256 indexed index,
        uint256 indexed timestamp,
        address indexed account
    );


    constructor(address _broker, address _oracleManager) {
        broker = IBroker(_broker);
        oracleManager = IOracleManager(_oracleManager);
    }

    function setExecutor(address executor, bool isActive) external _onlyAdmin_ {
        isExecutor[executor] = isActive;
        emit SetExecutor(executor, isActive);
    }

    function setExecutionFee(uint256 newExecutionFee) external _onlyAdmin_ {
        executionFee = newExecutionFee;
    }

    function setMaxDelayTime(uint256 newMaxDelayTime) external _onlyAdmin_ {
        maxDelayTime = newMaxDelayTime;
    }

    function collectFees() external _onlyAdmin_ {
        if (unclaimedFee > 0) {
            unclaimedFee = 0;
            _transferOutETH(unclaimedFee, msg.sender);
        }
    }

    function requestTrade(
        address pool,
        address asset,
        int256 amount,
        string calldata symbolName,
        int256[] calldata tradeParams
    ) external payable {
        uint256 timestamp = block.timestamp;
        address account = msg.sender;
        uint256 executionFee_;
        if (amount > 0 && asset == address(0)) {
            require(
                msg.value >= amount.itou(),
                "router: insufficient ETH amount"
            );
            executionFee_ = msg.value - amount.itou();
        } else {
            executionFee_ = msg.value;
        }
        require(
            executionFee_ >= executionFee,
            "router: insufficient executionFee"
        );

        if (amount > 0 && asset != address(0)) {
            require(
                IERC20(asset).allowance(msg.sender, address(broker)) >=
                    amount.itou(),
                "router: insufficient allowance"
            );
        }

        tradeIndex++;
        requestTradesNew[tradeIndex] = RequestTradeNew(
            tradeIndex,
            timestamp,
            pool,
            account,
            asset,
            amount,
            symbolName,
            executionFee_,
            tradeParams
        );

        string[] memory symbolNames = new string[](1);
        symbolNames[0] = symbolName;
        emit CreateRequestTrade(
            tradeIndex,
            timestamp,
            account,
            symbolNames
        );
    }

    function tryExecuteTrade(uint256 index, address executor) public {
        require(msg.sender == address(this), "router: should be internal call");

        RequestTradeNew memory request = requestTradesNew[index];

        require(
            request.timestamp + maxDelayTime >= block.timestamp,
            "router: request expired"
        );

        bytes32 symbolId = keccak256(abi.encodePacked(request.symbolName));
        if (request.amount > 0 && request.asset == address(0)) {
            broker.addMargin{value: request.amount.itou()}(
                request.account,
                request.pool,
                symbolId,
                request.asset,
                request.amount
            );
        } else if (request.amount > 0) {
            broker.addMargin(
                request.account,
                request.pool,
                symbolId,
                request.asset,
                request.amount
            );
        }

        address client = broker.clients(
            request.account,
            request.pool,
            symbolId,
            request.asset
        );
        require(client != address(0), "router: client not found");
        bool closed;
        if (request.tradeParams[0] != 0) {
            IPool(request.pool).trade(
                client,
                request.symbolName,
                request.tradeParams
            );
            ISymbolComplement.Position memory pos = broker.getPosition(
                request.account,
                request.pool,
                symbolId,
                request.asset
            );
            if (pos.volume == 0) {
                closed = true;
            }
        }
        if (closed || request.amount < 0) {
            broker.removeMargin(
                request.account,
                request.pool,
                request.asset,
                request.amount,
                client,
                closed
            );
        }

        _transferOutETH(request.executionFee, executor);

        //  futures/option/power: [tradeVolume, priceLimit]
        //  gamma: [tradeVolume, entryPrice, powerPriceLimit, futuresPriceLimit]
        int256 priceLimit;
        if (request.tradeParams.length > 2) {
            priceLimit = request.tradeParams[3];
        } else {
            priceLimit = request.tradeParams[1];
        }

        broker.emitTradeEvent(
            request.account,
            request.pool,
            request.asset,
            request.amount,
            request.symbolName,
            request.tradeParams[0],
            priceLimit,
            client
        );
        emit TradeWithMargin(
            request.account,
            request.pool,
            request.asset,
            request.amount,
            request.symbolName,
            request.tradeParams[0],
            priceLimit,
            client
        );

        emit ExecuteTrade(
            request.index,
            request.timestamp,
            request.account
        );
    }

    function tryCancelTrade(uint256 index) public {
        require(msg.sender == address(this), "router: should be internal call");
        RequestTradeNew memory request = requestTradesNew[index];

        if (request.amount > 0 && request.asset == address(0)) {
            _transferOutETH(request.amount.itou(), request.account);
        }
        unclaimedFee += request.executionFee;

        emit CancelTrade(
            request.index,
            request.timestamp,
            request.account
        );
    }

    function executeTrade(
        uint256 endIndex,
        OracleSignature[] memory oracleSignatures
    ) external _reentryLock_ {
        uint256 startIndex = lastExecutedIndex + 1;
        if (endIndex > tradeIndex) {
            endIndex = tradeIndex;
        }
        require(startIndex <= endIndex, "router: invalid request index");
        address executor = msg.sender;
        require(isExecutor[executor], "router: executor only");

        RequestTradeNew memory request = requestTradesNew[endIndex];
        require(request.account != address(0), "router: request not exist");

        _updateOraclesWithTimestamp(request.timestamp, oracleSignatures);

        while (startIndex <= endIndex) {
            try this.tryExecuteTrade(startIndex, executor) {} catch Error(
                string memory reason
            ) {
                emit ErrorString(startIndex, reason);
                try this.tryCancelTrade(startIndex) {} catch {}
            } catch (bytes memory reason) {
                emit LowLevelString(startIndex, reason);
                try this.tryCancelTrade(startIndex) {} catch {}
            }

            delete requestTradesNew[startIndex];
            startIndex++;
        }
        lastExecutedIndex = endIndex;
    }

    function _updateOraclesWithTimestamp(
        uint256 requestTimestamp,
        OracleSignature[] memory oracleSignatures
    ) internal {
        for (uint256 i = 0; i < oracleSignatures.length; i++) {
            OracleSignature memory signature = oracleSignatures[i];
            if (
                oracleManager.timestamp(signature.oracleSymbolId) <
                requestTimestamp
            ) {
                require(
                    signature.timestamp == requestTimestamp,
                    "router: invalid oracle timestamp"
                );
                oracleManager.updateValue(
                    signature.oracleSymbolId,
                    signature.timestamp,
                    signature.value,
                    signature.v,
                    signature.r,
                    signature.s
                );
            }
        }
    }

    function _transferOutETH(uint256 amountOut, address receiver) internal {
        (bool success, ) = payable(receiver).call{value: amountOut}("");
        require(success, "router: send ETH fail");
    }
}