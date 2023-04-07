//SPDX-License-Identifier: MIT

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

/*
* Whitelist of Fee On Transfer Token
*/
contract WhitelistFeeOnTransfer is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event AddFeeOnTransferToken(IERC20 indexed token);
    event DisabledFeeOnTransferToken(IERC20 indexed token);

    mapping(address => bool) public FeeOnTransferToken;

    function addFeeOnTransferToken(
        IERC20  token
    )
        public
        onlyOwner
    {
        FeeOnTransferToken[address(token)] = true;
        emit AddFeeOnTransferToken(token);
    }

    function disableFeeOnTransferToken(
        IERC20  token
    )
        public
        onlyOwner
    {
        FeeOnTransferToken[address(token)] = false;
        emit DisabledFeeOnTransferToken(token);
    }

    function isFeeOnTransferToken(IERC20 token)
        public
        view
        returns (bool)
    {
        return FeeOnTransferToken[address(token)];
    }
}