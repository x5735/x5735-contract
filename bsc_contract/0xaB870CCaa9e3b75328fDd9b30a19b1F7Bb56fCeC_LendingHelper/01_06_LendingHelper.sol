// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../library/SafeRatioMath.sol";

import "./interface/IDForceLending.sol";

/**
 * @notice The contract provides asset and user data in the lending market
 * @author dForce
 */
contract LendingHelper {
    using SafeMathUpgradeable for uint256;
    using SafeRatioMath for uint256;

    uint256 public constant USDPrice = 1 ether;

    function getAccountBorrowStatus(
        IControllerHelper controller,
        address _account
    ) public view returns (bool) {
        IiTokenHelper[] memory _iTokens = controller.getAlliTokens();
        for (uint256 i = 0; i < _iTokens.length; i++)
            if (_iTokens[i].borrowBalanceStored(_account) > 0) return true;

        return false;
    }

    struct AccountEquityLocalVars {
        IiTokenHelper[] collateralITokens;
        IiTokenHelper[] borrowedITokens;
        uint256 collateralFactor;
        uint256 borrowFactor;
        uint256 sumCollateral;
        uint256 sumBorrowed;
    }

    function calcAccountEquity(IControllerHelper _controller, address _account)
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        AccountEquityLocalVars memory _var;
        _var.collateralITokens = _controller.getEnteredMarkets(_account);
        for (uint256 i = 0; i < _var.collateralITokens.length; i++) {
            (_var.collateralFactor, , , , , , ) = _controller.markets(
                _var.collateralITokens[i]
            );
            _var.sumCollateral = _var.sumCollateral.add(
                _var.collateralITokens[i]
                    .balanceOf(_account)
                    .mul(
                    _controller.priceOracle().getUnderlyingPrice(
                        _var.collateralITokens[i]
                    )
                )
                    .rmul(_var.collateralITokens[i].exchangeRateStored())
                    .rmul(_var.collateralFactor)
            );
        }
        _var.borrowedITokens = _controller.getBorrowedAssets(_account);
        for (uint256 i = 0; i < _var.borrowedITokens.length; i++) {
            (, _var.borrowFactor, , , , , ) = _controller.markets(
                _var.borrowedITokens[i]
            );
            _var.sumBorrowed = _var.sumBorrowed.add(
                _var.borrowedITokens[i]
                    .borrowBalanceStored(_account)
                    .mul(
                    _controller.priceOracle().getUnderlyingPrice(
                        _var.borrowedITokens[i]
                    )
                )
                    .rdiv(_var.borrowFactor)
            );
        }
        return
            _var.sumCollateral > _var.sumBorrowed
                ? (
                    _var.sumCollateral - _var.sumBorrowed,
                    uint256(0),
                    _var.sumCollateral,
                    _var.sumBorrowed
                )
                : (
                    uint256(0),
                    _var.sumBorrowed - _var.sumCollateral,
                    _var.sumCollateral,
                    _var.sumBorrowed
                );
    }

    struct AccountEquityVars {
        uint256 USDPrice;
        uint256 euqity;
        uint256 shortfall;
        uint256 sumCollateral;
        uint256 sumBorrowed;
    }

    function getAccountEquity(IControllerHelper _controller, address _account)
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        AccountEquityVars memory _var;
        (
            _var.euqity,
            _var.shortfall,
            _var.sumCollateral,
            _var.sumBorrowed
        ) = calcAccountEquity(_controller, _account);
        return (
            _var.euqity,
            _var.shortfall,
            _var.sumCollateral.div(USDPrice),
            _var.sumBorrowed.div(USDPrice)
        );
    }

    function getAccountCurrentEquity(IiTokenHelper _asset, address _account)
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        _asset.updateInterest();
        return getAccountEquity(_asset.controller(), _account);
    }

    struct AvailableBalanceLocalVars {
        IControllerHelper controller;
        uint256 collateralFactor;
        uint256 assetPrice;
        uint256 accountEquity;
        uint256 sumCollateral;
        uint256 sumBorrowed;
        uint256 availableAmount;
        uint256 balance;
    }

    function getAvailableBalance(
        IiTokenHelper _iToken,
        address _account,
        uint256 _safeMaxFactor
    ) public returns (uint256) {
        AvailableBalanceLocalVars memory _var;
        _var.balance = _iToken.balanceOf(_account);
        _var.controller = _iToken.controller();
        (_var.collateralFactor, , , , , , ) = _var.controller.markets(_iToken);
        if (
            _var.controller.hasEnteredMarket(_account, _iToken) &&
            getAccountBorrowStatus(_var.controller, _account)
        ) {
            (
                _var.accountEquity,
                ,
                _var.sumCollateral,
                _var.sumBorrowed
            ) = calcAccountEquity(_var.controller, _account);
            if (_var.collateralFactor == 0 && _var.accountEquity > 0)
                return _var.balance;

            _var.assetPrice = _var.controller.priceOracle().getUnderlyingPrice(
                _iToken
            );
            if (
                _var.assetPrice == 0 ||
                _var.collateralFactor == 0 ||
                _var.accountEquity == 0
            ) return 0;

            _var.availableAmount = _var.sumCollateral >
                _var.sumBorrowed.rdiv(_safeMaxFactor)
                ? _var.sumCollateral.sub(_var.sumBorrowed.rdiv(_safeMaxFactor))
                : 0;

            _var.availableAmount = _var
                .availableAmount
                .div(_var.assetPrice)
                .rdiv(_var.collateralFactor)
                .rdiv(_iToken.exchangeRateStored());
            return
                _var.balance > _var.availableAmount
                    ? _var.availableAmount
                    : _var.balance;
        }

        return _var.balance;
    }

    struct interestDataVars {
        IInterestRateModelHelper interestRateModel;
        uint256 assetPrice;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 cash;
        uint256 base;
        uint256 optimal;
        uint256 slope_1;
        uint256 slope_2;
    }

    function getAssetInterestData(IiTokenHelper _asset)
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        interestDataVars memory _var;

        _var.assetPrice = _asset.controller().priceOracle().getUnderlyingPrice(
            _asset
        );
        _var.totalBorrows = _asset
            .totalBorrowsCurrent()
            .mul(_var.assetPrice)
            .div(USDPrice);
        _var.totalReserves = _asset.totalReserves().mul(_var.assetPrice).div(
            USDPrice
        );
        _var.cash = _asset.getCash().mul(_var.assetPrice).div(USDPrice);

        if (_asset.isiToken()) {
            _var.interestRateModel = _asset.interestRateModel();
            _var.base = _var.interestRateModel.base();
            _var.optimal = _var.interestRateModel.optimal();
            _var.slope_1 = _var.interestRateModel.slope_1();
            _var.slope_2 = _var.interestRateModel.slope_2();
        }
        return (
            _var.totalBorrows,
            _var.totalReserves,
            _var.cash,
            _asset.reserveRatio(),
            _var.base,
            _var.optimal,
            _var.slope_1,
            _var.slope_2
        );
    }
}