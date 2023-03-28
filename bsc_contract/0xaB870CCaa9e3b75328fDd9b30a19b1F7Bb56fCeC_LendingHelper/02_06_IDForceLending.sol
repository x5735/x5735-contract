//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../../interface/IInterestRateModelInterface.sol";

interface IInterestRateModelHelper is IInterestRateModelInterface {
    function blocksPerYear() external view returns (uint256);

    function base() external view returns (uint256);

    function optimal() external view returns (uint256);

    function slope_1() external view returns (uint256);

    function slope_2() external view returns (uint256);
}

interface IControllerHelper {
    function getAlliTokens() external view returns (IiTokenHelper[] memory);

    function getEnteredMarkets(address _account)
        external
        view
        returns (IiTokenHelper[] memory);

    function getBorrowedAssets(address _account)
        external
        view
        returns (IiTokenHelper[] memory);

    function hasEnteredMarket(address _account, IiTokenHelper _iToken)
        external
        view
        returns (bool);

    function hasBorrowed(address _account, IiTokenHelper _iToken)
        external
        view
        returns (bool);

    function priceOracle() external view returns (IPriceOracleHelper);

    function markets(IiTokenHelper _asset)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            bool
        );

    function calcAccountEquity(address _account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function closeFactorMantissa() external view returns (uint256);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function rewardDistributor()
        external
        view
        returns (IRewardDistributorHelper);
}

interface IiTokenHelper {
    function decimals() external view returns (uint8);

    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function isSupported() external view returns (bool);

    function isiToken() external view returns (bool);

    function underlying() external view returns (IERC20Upgradeable);

    function getCash() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function balanceOfUnderlying(address _account) external returns (uint256);

    function borrowBalanceStored(address _account)
        external
        view
        returns (uint256);

    function borrowBalanceCurrent(address _account) external returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function updateInterest() external returns (bool);

    function controller() external view returns (IControllerHelper);

    function interestRateModel()
        external
        view
        returns (IInterestRateModelHelper);

    function reserveRatio() external view returns (uint256);

    function originationFeeRatio() external view returns (uint256);

    function collateral() external view returns (IiTokenHelper);
}

interface IRewardDistributorHelper {
    function updateDistributionState(IiTokenHelper _iToken, bool _isBorrow)
        external;

    function updateReward(
        IiTokenHelper _iToken,
        address _account,
        bool _isBorrow
    ) external;

    function updateRewardBatch(
        address[] memory _holders,
        IiTokenHelper[] memory _iTokens
    ) external;

    function distributionSpeed(IiTokenHelper _iToken)
        external
        view
        returns (uint256);

    function distributionSupplySpeed(IiTokenHelper _iToken)
        external
        view
        returns (uint256);

    function reward(address _account) external view returns (uint256);

    function rewardToken() external view returns (IiTokenHelper);
}

interface IPriceOracleHelper {
    /**
     * @notice Get the underlying price of a iToken asset
     * @param _iToken The iToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(IiTokenHelper _iToken)
        external
        returns (uint256);

    /**
     * @notice Get the price of a underlying asset
     * @param _iToken The iToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable and whether the price is valid.
     */
    function getUnderlyingPriceAndStatus(IiTokenHelper _iToken)
        external
        returns (uint256, bool);

    function getAssetPriceStatus(IiTokenHelper _iToken)
        external
        view
        returns (bool);
}