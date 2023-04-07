//SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./RoutingManagement.sol";

/*
* Fee collection by partner reference
*/
contract Partnership is RoutingManagement {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
    * @dev Platform Fee collection
    * @param token Token address
    * @param wallet Partner or Wallet provider wallet
    * @param amount Fee amount
    */
    event CollectFee(
      IERC20   indexed token,
      address indexed wallet,
      uint256         amount
    );

    /**
    * @dev Updating partner info
    * @param wallet Partner wallet
    * @param name partner name
    */
    event UpdatePartner(
      address indexed wallet,
      bytes16 name
    );

    struct Partner {
      address wallet;       // To receive fee on the Warden Swap network
      bytes16 name;         // Partner reference
    }

    IERC20 public constant etherERC20 = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint256 public constant FEE_DIVIDER = 1e6;

    Partner public partners;

    constructor() public {
        partners = Partner(msg.sender, "KALM"); // 0.1%
        emit UpdatePartner(msg.sender, "KALM");
    }

    function updatePartner(address wallet, bytes16 name)
        external
        onlyOwner
    {
        partners = Partner(wallet, name);
        emit UpdatePartner(wallet, name);
    }

    function _amountWithFee(uint256 amount, uint256 _fee)
        internal
        view
        returns(uint256 remainingAmount)
    {

        if (_fee == 0) {
            return amount;
        }
        uint256 fee = amount.mul(_fee).div(FEE_DIVIDER).div(100);
        return amount.sub(fee);
    }

    function _collectFee(uint256 amount, IERC20 token, uint256 _fee)
        internal
        returns(uint256 remainingAmount)
    {
        if (_fee == 0) {
            return amount;
        }

        uint256 fee = amount.mul(_fee).div(FEE_DIVIDER).div(100);
        require(fee < amount, "fee exceeds return amount!");
        if (etherERC20 == token) {
            (bool success, ) = partners.wallet.call.value(fee)(""); // Send back ether to sender
            require(success, "Transfer fee of ether failed.");
        } else {
            token.safeTransfer(partners.wallet, fee);
        }
        emit CollectFee(token, partners.wallet, fee);

        return amount.sub(fee);
    }
}