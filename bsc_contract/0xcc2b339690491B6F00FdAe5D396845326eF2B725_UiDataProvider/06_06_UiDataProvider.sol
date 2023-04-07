// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IGrainLGE.sol";
import "./interfaces/IGrainSaleClaim.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UiDataProvider {
    uint256 public constant PERIOD = 91 days;
    uint256 public constant MAX_KINK_RELEASES = 8;
    uint256 public constant MAX_RELEASES = 20;
    uint256 public constant maxKinkDiscount = 4e26;
    uint256 public constant maxDiscount = 6e26;
    uint256 public constant PERCENT_DIVISOR = 1e27;
    IGrainLGE public immutable lge;
    IGrainSaleClaim public immutable grainSaleClaim;

    struct UserData {
        uint256 numberOfReleases;
        uint256 totalOwed;
        uint256 pending;
        uint256 totalClaimed;
        uint256 userGrainLeft;
    }

    constructor(address _lge, address _grainSaleClaim) {
        lge = IGrainLGE(_lge);
        grainSaleClaim = IGrainSaleClaim(_grainSaleClaim);
    }
    
    // @dev: this function is used to get the user's total weight
    // @param user: the user's address
    function getUserTotalWeight(address user) public view returns (uint256 totalWeight) {
        (uint256 usdcValue, uint256 numberOfReleases,,, address nft,) = lge.userShares(user);

        uint256 whitelistedBonuses = lge.whitelistedBonuses(nft);

        uint256 vestingPremium;
        if (numberOfReleases == 0) {
            vestingPremium = 0;
        } else if (numberOfReleases <= MAX_KINK_RELEASES) {
            // range from 0 to 40% discount
            vestingPremium = maxKinkDiscount * numberOfReleases / MAX_KINK_RELEASES;
        } else if (numberOfReleases <= MAX_RELEASES) {
            // range from 40% to 60% discount
            // ex: user goes for 20 (5 years) -> 60%
            vestingPremium = (((maxDiscount - maxKinkDiscount) * (numberOfReleases - MAX_KINK_RELEASES)) / (MAX_RELEASES - MAX_KINK_RELEASES)) + maxKinkDiscount;
        }

        uint256 weight = vestingPremium == 0 ? usdcValue : usdcValue * PERCENT_DIVISOR / (PERCENT_DIVISOR - vestingPremium);

        uint256 bonusWeight = nft == address(0) ? 0 : weight * whitelistedBonuses / PERCENT_DIVISOR;

        totalWeight = weight + bonusWeight;
    }

    // @dev: this function is used to get the number of releases
    // @param user: the user's address
    function getNumberOfReleases(address user) public view returns (uint256 numberOfReleases) {
        (, numberOfReleases,,,,) = lge.userShares(user);
    }

    // @dev: this function is used to get the total owed
    // @param user: the user's address
    function getTotalOwed(address user) public view returns (uint256 userTotal) {
        uint256 userTotalWeight = getUserTotalWeight(user);
        uint256 totalWeight = grainSaleClaim.cumulativeWeight();
        uint256 totalGrain = grainSaleClaim.totalGrain();
        uint256 shareOfLge = userTotalWeight * PERCENT_DIVISOR / totalWeight;
        userTotal = (shareOfLge * totalGrain) / PERCENT_DIVISOR;
    }

    // @dev: this function is used to get the pending
    // @param user: the user's address
    function getPending(address user) public view returns (uint256 claimable) {
        (, uint256 numberOfReleases,,,,) = lge.userShares(user);
        (,, uint256 totalClaimed) = grainSaleClaim.userShares(user);
        uint256 lgeEnd = grainSaleClaim.lgeEnd();

        /// Get how many periods user is claiming
        if (numberOfReleases == 0) {
            // No vest
            claimable = getTotalOwed(user) - totalClaimed;
        } else {
            // Vest
            uint256 periodsSinceEnd = (block.timestamp - lgeEnd) / PERIOD;
            if(periodsSinceEnd > numberOfReleases){
                periodsSinceEnd = numberOfReleases;
            }
            claimable = (getTotalOwed(user) * periodsSinceEnd / numberOfReleases) - totalClaimed;
        }
    }

    // @dev: this function is used to get the total claimed
    // @param user: the user's address
    function getTotalClaimed(address user) public view returns (uint256 totalClaimed) {
        (,, uint256 claimed) = grainSaleClaim.userShares(user);
        totalClaimed = claimed;
    }

    // @dev: this function is used to get the user's grain left
    // @param user: the user's address
    function getUserGrainLeft(address user) public view returns (uint256 grainLeft) {
        (,, uint256 totalClaimed) = grainSaleClaim.userShares(user);
        grainLeft = getTotalOwed(user) - totalClaimed;
    }

    // @dev: this function is used to get the user's data
    // @param user: the user's address
    function getUserData(address user) public view returns (UserData memory userData) {
        userData.numberOfReleases = getNumberOfReleases(user);
        userData.totalOwed = getTotalOwed(user);
        userData.pending = getPending(user);
        userData.totalClaimed = getTotalClaimed(user);
        userData.userGrainLeft = getUserGrainLeft(user);
    }
}