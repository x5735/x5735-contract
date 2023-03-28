// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IFeeConfig.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/ISolidlyRouter.sol";
import "../interfaces/IVeToken.sol";
import "../interfaces/IVeDist.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/ICpveTHEConfigurator.sol";

contract CpveTHEConfigurator is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    uint256 public constant MAX_RATE = 1e18;
    uint256 public constant MAX = 10000; // 100%

    mapping(address => ICpveTHEConfigurator.Gauges) public gauges;
    mapping(address => bool) public lpInitialized;
    mapping(address => ISolidlyRouter.Routes[]) public routes;
    ISolidlyRouter.Routes[] public wantToNativeRoute;

    ISolidlyRouter public router;
    IVoter public solidVoter;
    IVeToken public ve;
    IVeDist public veDist;
    IERC20Upgradeable public want;

    address public coFeeRecipient;
    IFeeConfig public coFeeConfig;

    uint256 public reserveRate;

    uint256 public minDuringTimeWithdraw;
    uint256 public redeemFeePercent;
    bool public isAutoIncreaseLock;

    uint256 public maxPeg;

    address[] public excluded;
    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    mapping (address => bool) public marketLpPairs;
    uint256 public taxSellingPercent;
    mapping(address => bool) public excludedSellingTaxAddresses;

    uint256 public taxBuyingPercent;
    mapping(address => bool) public excludedBuyingTaxAddresses;

    event SetRedeemFeePercent(uint256 oldValue, uint256 newValue);
    event SetMinDuringTimeWithdraw(uint256 oldValue, uint256 newValue);
    event SetMaxPeg(uint256 oldValue, uint256 newValue);
    event SetReserveRate(uint256 oldValue, uint256 newValue);
    event SetTaxSellingPercent(uint256 oldValue, uint256 newValue);
    event SetTaxBuyingPercent(uint256 oldValue, uint256 newValue);
    event SetFeeRecipient(address oldRecipient, address newRecipient);
    event SetFeeId(uint256 id);
    event AutoIncreaseLock(bool _enabled);

    event GrantExclusion(address indexed account);
    event RevokeExclusion(address indexed account);

    event SetRouter(address oldRouter, address newRouter);
    event AddedGauge(address gauge, address feeGauge, address[] bribeTokens, address[] feeTokens);
    event AddedRewardToken(address token);

    function initialize(
        address _solidVoter, 
        address _router, 
        address _coFeeConfig, 
        address _coFeeRecipient,
        ISolidlyRouter.Routes[] memory _wantToNativeRoute
    ) public initializer {
        __Ownable_init();
        solidVoter = IVoter(_solidVoter);
        ve = IVeToken(solidVoter._ve());
        want = IERC20Upgradeable(ve.token());
        IMinter _minter = IMinter(solidVoter.minter());
        veDist = IVeDist(_minter._rewards_distributor());
        router = ISolidlyRouter(_router);

        coFeeRecipient = _coFeeRecipient;
        coFeeConfig = IFeeConfig(_coFeeConfig);

        for (uint i; i < _wantToNativeRoute.length; i++) {
            wantToNativeRoute.push(_wantToNativeRoute[i]);
        }

        redeemFeePercent = 200; // 2%
        isAutoIncreaseLock = true;
        maxPeg = 0.85e18;
        reserveRate = 2000; // 20%
        taxBuyingPercent = 100; // 1%
        taxSellingPercent = 100; // 1%

        excluded.push(deadWallet);
    }

    function setRedeemFeePercent(uint256 _rate) external onlyOwner {
        // validation from 0-2%
        require(_rate <= 200, "CpveTHEConfigurator: RATE_OUT_OF_RANGE");
        emit SetRedeemFeePercent(redeemFeePercent, _rate);
        redeemFeePercent = _rate;
    }
    
    function setMinDuringTimeWithdraw(uint256 _seconds) external onlyOwner {
        // validation from 0-24h
        require(_seconds <= 24 hours, "CpveTHEConfigurator: OUT_OF_RANGE");
        emit SetMinDuringTimeWithdraw(minDuringTimeWithdraw, _seconds);
        minDuringTimeWithdraw = _seconds;
    }

    function setAutoIncreaseLock(bool _enabled) external onlyOwner {
        isAutoIncreaseLock = _enabled;
        emit AutoIncreaseLock(_enabled);
    }

    function setMaxPeg(uint256 _value) external onlyOwner {
        // validation from 0-1
        require(_value <= 1e18, "CpveTHEConfigurator: VALUE_OUT_OF_RANGE");
        emit SetMaxPeg(maxPeg, _value);
        maxPeg = _value;
    }

    function adjustReserve(uint256 _rate) external onlyOwner {
        // validation from 0-50%
        require(_rate <= 5000, "CpveTHEConfigurator: OUT_OF_RANGE");
        emit SetReserveRate(reserveRate, _rate);
        reserveRate = _rate;
    }

    // Add new LP's for selling / buying fees
    function setMarketLpPairs(address _pair, bool _value) public onlyOwner {
        marketLpPairs[_pair] = _value;
    }

    function setTaxBuyingPercent(uint256 _value) external onlyOwner {
		require(_value <= 100, "Max tax is 1%");
        emit SetTaxBuyingPercent(taxBuyingPercent, _value);
        taxBuyingPercent = _value;
    }

    function setTaxSellingPercent(uint256 _value) external onlyOwner {
		require(_value <= 100, "Max tax is 1%");
        emit SetTaxSellingPercent(taxSellingPercent, _value);
        taxSellingPercent = _value;
    }

    function excludeBuyingTaxAddress(address _address) external onlyOwner {
        excludedBuyingTaxAddresses[_address] = true;
    }

    function excludeSellingTaxAddress(address _address) external onlyOwner {
        excludedSellingTaxAddresses[_address] = true;
    }

    function includeBuyingTaxAddress(address _address) external onlyOwner {
        excludedBuyingTaxAddresses[_address] = false;
    }

    function includeSellingTaxAddress(address _address) external onlyOwner {
        excludedSellingTaxAddresses[_address] = false;
    }

    function grantExclusion(address account) external onlyOwner {
        excluded.push(account);
        emit GrantExclusion(account);
    }

    function revokeExclusion(address account) external onlyOwner {
        uint256 excludedLength = excluded.length;
        for (uint256 i = 0; i < excludedLength; i++) {
            if (excluded[i] == account) {
                excluded[i] = excluded[excludedLength - 1];
                excluded.pop();
                emit RevokeExclusion(account);
                return;
            }
        }
    }

    function setFeeId(uint256 id) external onlyOwner {
        emit SetFeeId(id);
        coFeeConfig.setStratFeeId(id);
    }

    function setCoFeeRecipient(address _feeRecipient) external onlyOwner {
        emit SetFeeRecipient(address(coFeeRecipient), _feeRecipient);
        coFeeRecipient = _feeRecipient;
    }

    // Add gauge
    function addGauge(address _lp, address[] calldata _bribeTokens, address[] calldata _feeTokens) external onlyOwner {
        address gauge = solidVoter.gauges(_lp);
        gauges[_lp] = ICpveTHEConfigurator.Gauges(solidVoter.external_bribes(gauge), solidVoter.internal_bribes(gauge), _bribeTokens, _feeTokens);
        lpInitialized[_lp] = true;
        emit AddedGauge(solidVoter.external_bribes(_lp), solidVoter.internal_bribes(_lp), _bribeTokens, _feeTokens);
    }

    // Add a reward token
    function addRewardToken(ISolidlyRouter.Routes[] calldata _route) public onlyOwner {
        require(_route[0].from != address(want), "CpveTHEConfigurator: ROUTE_FROM_IS_TOKEN_WANT");
        require(_route[_route.length - 1].to == address(want), "CpveTHEConfigurator: ROUTE_TO_NOT_TOKEN_WANT");
        for (uint i; i < _route.length; i++) {
            routes[_route[0].from].push(_route[i]);
        }
        emit AddedRewardToken(_route[0].from);
    }

    // Delete a reward token
    function deleteRewardToken(address _token) external onlyOwner {
        delete routes[_token];
    }

    // Add multiple reward tokens
    function addMultipleRewardTokens(ISolidlyRouter.Routes[][] calldata _routes) external onlyOwner {
        for (uint i; i < _routes.length; i++) {
            addRewardToken(_routes[i]);
        }
    }
    
    // Set our router to exchange our rewards, also update new thenaToNative route.
    function setRouterAndRoute(address _router, ISolidlyRouter.Routes[] calldata _route) external onlyOwner {
        emit SetRouter(address(router), _router);
        for (uint i; i < wantToNativeRoute.length; i++) wantToNativeRoute.pop();
        for (uint i; i < _route.length; i++) wantToNativeRoute.push(_route[i]);
        router = ISolidlyRouter(_router);
    }

    function hasSellingTax(address _from, address _to) external view returns (uint256) {
        if(marketLpPairs[_to] && !excludedSellingTaxAddresses[_from] && taxSellingPercent > 0) {
            return taxSellingPercent;
        }

        return 0;
    }

    function hasBuyingTax(address _from, address _to) external view returns (uint256) {
        if(marketLpPairs[_from] && !excludedBuyingTaxAddresses[_to] && taxBuyingPercent > 0) {
            return taxBuyingPercent;
        }

        return 0;
    }

    function getExcluded() external view returns (address[] memory) {
        return excluded;
    }

    function getFee() external view returns (uint256) {
        IFeeConfig.FeeCategory memory fees = coFeeConfig.getFees(address(this));
        return fees.total;
    }

    function getGauges(address _lp) external view returns (ICpveTHEConfigurator.Gauges memory) {
        return gauges[_lp];
    }

    function getRoutes(address _token) external view returns (ISolidlyRouter.Routes[] memory) {
        if (_token == address(want)) return wantToNativeRoute;
        return routes[_token];
    }
}