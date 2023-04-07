// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TokenHelper.sol";
import "../Constant.sol";


contract MultiSigWithdrawable is TokenHelper, Ownable {

    event MultiSigWithdraw(uint amount, address to);
    event MultiSigWithdrawToken(address token, uint amount, address to);

    function multiSigWithdrawToken(address token, uint amount, address to) external onlyOwner {

        _transferTokenOut(token, amount, to);
        emit MultiSigWithdrawToken(token, amount, to);
    }
}