// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBKTreasury {
    error BKTreasury__LengthMismatch();
    error BKTreasury__UnsupportedToken();

    event PaymentsUpdated(
        address indexed operator,
        address[] payments,
        bool[] statuses
    );
    event PricesUpdated(
        address indexed operator,
        address[] tokens,
        uint256[] prices
    );

    function priceOf(address token_) external view returns (uint256);

    function supportedPayment(address token_) external view returns (bool);

    function viewSupportedPayments() external view returns (address[] memory);
}