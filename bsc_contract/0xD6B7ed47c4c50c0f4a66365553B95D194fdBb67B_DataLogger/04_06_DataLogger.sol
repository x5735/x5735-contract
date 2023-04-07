// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;


import "../base/Controllable.sol";
import "../interfaces/IDataLog.sol";

// Transfer this ownership to DAO MultiSig
contract DataLogger is IDataLog, Controllable {

    mapping (address => bool) public allowedSource;

    event SetSource(address source, bool allowed);
    event Log(address indexed fromContract, address indexed fromUser, uint indexed source, uint action, uint data1, uint data2);

    constructor(address control)
    {
        changeController(control);
    }

    function setSource(address source, bool allowed) external onlyController {
        allowedSource[source] = allowed;
        emit SetSource(source, allowed);
    }

    function log(address fromContract, address fromUser, uint source, uint action, uint data1, uint data2) external {
        require(allowedSource[msg.sender], "Not allowed to log");
        emit Log(fromContract, fromUser, source, action, data1, data2);
    }
}