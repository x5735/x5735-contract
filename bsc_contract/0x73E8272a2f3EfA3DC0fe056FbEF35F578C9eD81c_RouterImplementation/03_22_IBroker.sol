// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../utils/INameVersion.sol";
import {ISymbolComplement} from "./BrokerImplementation.sol";

interface IBroker is INameVersion {
    function addMargin(
        address account,
        address pool,
        bytes32 symbolId,
        address asset,
        int256 amount
    ) external payable;

    function removeMargin(
        address account,
        address pool,
        address asset,
        int256 amount,
        address client,
        bool closed
    ) external;

    function tradeWithMargin(
        address account,
        address pool,
        address asset,
        int256 amount,
        string memory symbolName,
        int256 tradeVolume,
        int256 priceLimit
    ) external payable;

    function emitTradeEvent(
        address account,
        address pool,
        address asset,
        int256 amount,
        string memory symbolName,
        int256 tradeVolume,
        int256 priceLimit,
        address client
    ) external;

    function clients(
        address account,
        address pool,
        bytes32 symbolId,
        address asset
    ) external view returns (address);

    function getPosition(
        address account,
        address pool,
        bytes32 symbolId,
        address asset
    ) external view returns (ISymbolComplement.Position memory position);
}