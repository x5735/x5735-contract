// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract ClaimStorage {
    address public token;

    address public tokenHolder;

    // exchangeRate extended by 1e18 and token decimals
    uint256 public exchangeRateMantissa;

    mapping(address => uint256) public claimedAmount;

    mapping(address => uint256) public claimedTokens;
}

abstract contract ClaimBase is ClaimStorage {
    uint256 public constant MANTISSA = 1e18;
    uint256 public constant MANTISSA2 = 1e36;

    event TokenChanged(address token);

    event TokenHolderChanged(address tokenHolder);

    event ExchangeRateChanged(uint256 exchangeRateMantissa);

    event Claim(
        address indexed recipient,
        uint256 nowClaimed,
        uint256 totalClaimed,
        uint256 nowTokens,
        uint256 totalTokens
    );

    function setTokenInternal(address token_) internal {
        token = token_;

        emit TokenChanged(token);
    }

    function setTokenHolderInternal(address tokenHolder_) internal {
        tokenHolder = tokenHolder_;

        emit TokenHolderChanged(tokenHolder);
    }

    function setExchangeRateInternal(uint256 exchangeRateMantissa_) internal {
        exchangeRateMantissa = exchangeRateMantissa_;

        emit ExchangeRateChanged(exchangeRateMantissa);
    }

    function claimAmountInternal(
        address recipient,
        uint256 cumulatedAmount
    ) internal {
        require(
            cumulatedAmount > claimedAmount[recipient],
            "Claim: NOTHING_TO_CLAIM"
        );

        uint256 amount = cumulatedAmount - claimedAmount[recipient];
        uint256 tokens = (amount * exchangeRateMantissa) / MANTISSA2;

        claimedAmount[recipient] = cumulatedAmount;
        claimedTokens[recipient] += tokens;

        require(
            IERC20(token).transferFrom(tokenHolder, recipient, tokens),
            "Claim: TRANSFER_FAILED"
        );

        emit Claim(
            recipient,
            amount,
            claimedAmount[recipient],
            tokens,
            claimedTokens[recipient]
        );
    }
}