// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/// @title Interface for any USD oracle
/// @author DFKassa Team
interface ITokenUsdOracle {
    /// Fetch token price with at 10**18
    /// @param _token: Token to check price
    /// @param _amount: Token amount to calculate result amount
    function calcE18(
        address _token,
        uint256 _amount
    ) external view returns (uint256 _priceInUsd, uint256 _amountInUsd);

    /// Fetch token price with at 10**2
    /// @param _token: Token to check price
    /// @param _amount: Token amount to calculate result amo
    function calcE2(
        address _token,
        uint256 _amount
    ) external view returns (uint256 _priceInUsd, uint256 _amountInUsd);
}