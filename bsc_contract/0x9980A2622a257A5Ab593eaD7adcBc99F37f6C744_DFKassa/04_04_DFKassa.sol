// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/// Tip data for DFKassa.pay function
struct Tip {
    address reciever;
    uint256 amount;
}

/// @title DFKassa V1 smart contract for transferring assets
/// @author DFKassa Team
contract DFKassa {

    /// NewPayment event emited when an invoice is paid
    /// All params are exactly from what were passed into function
    event NewPayment(
        uint256 indexed payload,
        address indexed merchant,
        uint256 amount,
        address token,
        Tip[] tips
    );

    /// Pay an off-chain invoice
    /// @param _merchant Address of assets reciever
    /// @param _token Address of assets. Zero for native currency
    /// @param _amount Asset's amount
    /// @param _payload Some extra data for off-chain checks
    /// @param _tips Extra native currency transfers (for example, for tips)
    function pay(
        address payable _merchant,
        address _token,
        uint256 _amount,
        uint256 _payload,
        Tip[] memory _tips
    ) public payable virtual {
        if (_token == address(0)) {
            payable(_merchant).transfer(_amount);
        } else {
            IERC20Metadata _erc20Contract = IERC20Metadata(_token);
            _erc20Contract.transferFrom(msg.sender, _merchant, _amount);
        }

        for (uint8 index; index < _tips.length; index++) {
            Tip memory tip = _tips[index];
            payable(tip.reciever).transfer(tip.amount);
        }

        emit NewPayment(
            _payload,
            _merchant,
            _amount,
            _token,
            _tips
        );
    }
}