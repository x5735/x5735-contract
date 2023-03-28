//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LibertiPriceFeed is Ownable, Multicall {
    mapping(address => address) public feeds;

    error AssetNotSupportedError();
    error FeedAlreadyExistsError();
    error NegativePriceError();
    error StalePriceError();

    event AddPriceFeed(address indexed token, address indexed feed);

    function addPriceFeed(address tokenAddr, address feedAddr) external onlyOwner {
        if (address(0) != feeds[tokenAddr]) {
            revert FeedAlreadyExistsError();
        }
        feeds[tokenAddr] = feedAddr;
        emit AddPriceFeed(tokenAddr, feedAddr);
    }

    function getPrice(address token) external view returns (uint256) {
        address feed = feeds[token];
        if (address(0) == feed) {
            revert AssetNotSupportedError();
        }
        (
            uint80 roundID,
            int256 answer,
            ,
            uint256 updatedAt, // updatedAt data feed property is the timestamp of an answered round
            uint80 answeredInRound // answeredInRound is the round it was updated in
        ) = AggregatorV3Interface(feed).latestRoundData();
        if (0 >= updatedAt) {
            // A timestamp with zero value means the round is not complete and should not be used.
            revert StalePriceError();
        }
        if (0 > answer) {
            revert NegativePriceError();
        }
        if (answeredInRound < roundID) {
            // If answeredInRound is less than roundId, the answer is being carried over. If
            // answeredInRound is equal to roundId, then the answer is fresh.
            revert StalePriceError();
        }
        return uint256(answer);
    }
}