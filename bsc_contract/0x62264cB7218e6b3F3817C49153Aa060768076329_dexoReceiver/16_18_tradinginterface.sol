// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./storageinterface.sol";
interface IDexoPosition {

    function _openTrade(
        dexoStorage.Trade memory t,
        uint orderType,
        uint slippageP, // for market orders only
        address sender
    ) external ;

    function _updateSl(
        uint pairIndex,
        uint index,
        uint newSl,
        address sender
    ) external;

    function _updateTp(
        uint pairIndex,
        uint index,
        uint newTp,
        address sender
    ) external;

    function _closeTradeByUser(
        uint pairIndex,
        uint index,
        uint slippageP,
        address sender
    )  external;

    function _cancelOrder(
        uint pairIndex,
        uint index,
        address sender
    )  external;

}