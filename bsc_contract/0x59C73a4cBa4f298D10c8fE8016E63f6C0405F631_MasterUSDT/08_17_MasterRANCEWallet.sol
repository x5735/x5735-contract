// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.2;

import "./interfaces/IBEP20.sol";
import './utils/SafeBEP20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract MasterRANCEWallet is Ownable {
    using SafeBEP20 for IBEP20;
    // The RANCE TOKEN!
    IBEP20 public RANCE;
    mapping (address => bool) public masters;

    constructor(
        IBEP20 _RANCE
    ) {
        RANCE = _RANCE;
    }

    function addMasterRANCE(address _MasterRANCE) onlyOwner external{
        masters[_MasterRANCE] = true;
    }

    function removeMasterRANCE(address _MasterRANCE) onlyOwner external{
        masters[_MasterRANCE] = false;
    }

    function safeTokenTransfer(address _to, uint256 _amount, IBEP20 _token) public returns(uint) {
        require(masters[msg.sender] || msg.sender == owner(), "Wallet: Only MasterRANCE and Owner can transfer");
        uint256 bal = _token.balanceOf(address(this));
        if (_amount > bal) {
            _token.safeTransfer(_to, bal);
            return bal;
        } else {
            _token.safeTransfer(_to, _amount);
            return _amount;
        }
    }

    // Safe RANCE transfer function, just in case if rounding error causes pool to not have enough RANCEs.
    function safeRANCETransfer(address _to, uint256 _amount) public returns(uint) {
        require(masters[msg.sender] || msg.sender == owner(), "Wallet: Only a MasterRANCE and Owner can transfer");
        uint256 RANCEBal = RANCE.balanceOf(address(this));
        if (_amount > RANCEBal) {
            RANCE.safeTransfer(_to, RANCEBal);
            return RANCEBal;
        } else {
            RANCE.safeTransfer(_to, _amount);
            return _amount;
        }
    }
}