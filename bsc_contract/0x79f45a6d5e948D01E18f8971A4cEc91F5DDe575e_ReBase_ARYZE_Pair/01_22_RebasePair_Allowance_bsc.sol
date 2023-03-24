// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./libraries/Math.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IDataFeed.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IRouter.sol";

//Jodi Usama Husain v1 for MAMA DeFi, to stabilize eEUR-eUSD pool to reflect the real market and stablize pair.

contract ReBase_ARYZE_Pair is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;
    using SafeMath for uint112;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address private _pair;
    address private _token0;
    address private _token1;
    address private _oracle0;
    address private _oracle1;
    address private _oracleNT;
    address private _treasury;
    address private _router;
    uint8 private _oracle0Decimal;
    uint8 private _oracle1Decimal;
    uint8 private _oracleNTDecimal;
    uint64 private _oracle0den;
    uint64 private _oracle1den;
    uint64 private _oracleNTden;
    uint256 private _minimumNetProfitUSD;

    event Rebased(uint256 profitUSD, uint256 netProfitUSD);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        address owner = msg.sender; // deployer
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(UPGRADER_ROLE, owner);
        setTreasury(owner); // treasury

        setRouter(0x1D0EAa1038BA77270EF9698Ec41d26b0d83eb705);
        setMinimumNetProfitUSD(0);

        address eEUR_eUSD_Pool = 0x97a8F133410cE466927687A5De40F96AB1367F88;
        address eEUR = 0x735fa792e731a2e8F83F32eb539841b7B72e6d8f;
        address eUSD = 0xa4335da338ec4C07C391Fc1A9bF75F306adadc08;
        address oracle_USD_USD = address(0);
        address oracle_EUR_USD = 0x0bf79F617988C472DcA68ff41eFe1338955b9A80;
        address oracle_BNB_USD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

        setPair(eEUR_eUSD_Pool, eEUR, eUSD, oracle_EUR_USD, oracle_USD_USD, oracle_BNB_USD);


    }

    function setMinimumNetProfitUSD(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _minimumNetProfitUSD = amount;
        return true;
    }

    function setTreasury(address treasury) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(treasury != address(0), "Zero address!");
        _treasury = treasury;
        return true;
    }

    function setRouter(address routerAddress) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(routerAddress != address(0));
        _router = routerAddress;
        return true;
    }

    function router() public view returns (address) {
        return _router;
    }

    /**
     * @dev Check allowance to spend tokens from treasury
     */
    function allowance() public view returns (uint256 token0, uint256 token1) {
        token0 = IERC20(address(_token0)).allowance(_treasury, address(this));
        token1 = IERC20(address(_token1)).allowance(_treasury, address(this));
    }

    /**
     * @param pair address of `pair`
     * @param oracle0 address of chainlink aggregator which can give FX rate for `token0` to USD in current chain
     * @param oracle1 address of chainlink aggregator which can give FX rate for `token1` to USD in current chain
     * @param oracleNT address of chainlink aggregator which can give FX rate for Native Token to USD in current chain
     */
    function setPair(
        address pair,
        address token0,
        address token1,
        address oracle0,
        address oracle1,
        address oracleNT
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(pair != address(0), "Pair address is zero");
        require(token0 != address(0), "Token0 address is zero");
        require(token1 != address(0), "Token1 address is zero");
        address t0 = IPair(pair).token0();
        address t1 = IPair(pair).token1();
        require((t0 == token0 && t1 == token1) || (t0 == token1 && t1 == token0), "Wrong pair or tokens");
        (_token0, _token1) = t0 == token0 ? (token0, token1) : (token1, token0);
        (_oracle0, _oracle1) = t0 == token0 ? (oracle0, oracle1) : (oracle1, oracle0);
        _pair = pair;
        _oracleNT = oracleNT;
        if (_oracle0 != address(0)) {
            uint8 oracle0Decimal = IDataFeed(_oracle0).decimals();
            require((oracle0Decimal == 8 || oracle0Decimal == 18), "Invalid _oracle0 decimals");
            _oracle0Decimal = oracle0Decimal;
            _oracle0den = uint64(10**_oracle0Decimal);
        } else {
            _oracle0Decimal = 0; // default value for USD
            _oracle0den = 1;
        }
        if (_oracle1 != address(0)) {
            uint8 oracle1Decimal = IDataFeed(_oracle1).decimals();
            require((oracle1Decimal == 8 || oracle1Decimal == 18), "Invalid _oracle1 decimals");
            _oracle1Decimal = oracle1Decimal;
            _oracle1den = uint64(10**_oracle1Decimal);
        } else {
            _oracle1Decimal = 0; // default value for USD
            _oracle1den = 1;
        }
        if (_oracleNT != address(0)) {
            uint8 oracleNTDecimal = IDataFeed(_oracleNT).decimals();
            require((oracleNTDecimal == 8 || oracleNTDecimal == 18), "Invalid oracleNT decimals");
            _oracleNTDecimal = oracleNTDecimal;
            _oracleNTden = uint64(10**_oracleNTDecimal);
        } else {
            _oracleNTDecimal = 0; // default value for USD
            _oracleNTden = 1;
        }
    }

    function getPair()
        external
        view
        returns (
            address,
            address,
            address,
            address,
            address,
            address,
            uint8,
            uint8,
            uint8
        )
    {
        return (
            _pair,
            _token0,
            _token1,
            _oracle0,
            _oracle1,
            _oracleNT,
            _oracle0Decimal,
            _oracle1Decimal,
            _oracleNTDecimal
        );
    }

    function rebaseOriginal() external whenNotPaused {
        (uint256 amountOut, uint256 amountInMax, address[] memory path, , , ) = _getRebaseAmount(_pair);
        require(path[0] != address(0), "Threshold not achieved");
        // check does enough allowance
        uint256 balance = IERC20(path[0]).allowance(_treasury, address(this));
        require(balance >= amountInMax, "Insufficient allowance");
        // set allowance for router to spend amountInMax
        bool allowed = IERC20(path[0]).approve(_router, amountInMax);
        require(allowed, "Can't get allowance");
        // transfer tokens to this contract to be able run swap as user
        bool transfered = IERC20(path[0]).transferFrom(_treasury, address(this), amountInMax);
        require(transfered, "Can't transfer funds");
        // try to swap tokens from this contract to _treasury
        IARYZE_Router02(_router).swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            _treasury,
            block.timestamp + 3600
        );

        balance = IERC20(path[0]).balanceOf(address(this));
        IERC20(path[0]).transfer(_treasury, balance);
    }

    function rebase() external whenNotPaused {
        (
            uint256 amountOut,
            uint256 amountInMax,
            address[] memory path,
            uint256 profitUSD,
            uint256 netProfitUSD,

        ) = _getRebaseAmount(_pair);
        require(path[0] != address(0), "Threshold not achieved");
        // check does enough allowance
        uint256 balance = IERC20(path[0]).allowance(_treasury, address(this));
        require(balance >= amountInMax, "Insufficient funds");
        // set allowance for router to spend amountInMax
        bool allowed = IERC20(path[0]).approve(_router, amountInMax);
        require(allowed, "Can't get allowance");
        // transfer tokens to this contract to be able run swap as user
        bool transfered = IERC20(path[0]).transferFrom(_treasury, address(this), amountInMax);
        require(transfered, "Can't transfer funds");
        // swap tokens from this contract to _treasury
        IARYZE_Router02(_router).swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            _treasury,
            block.timestamp + 3600
        );
        balance = IERC20(path[0]).balanceOf(address(this));
        IERC20(path[0]).transfer(_treasury, balance);
        emit Rebased(profitUSD, netProfitUSD);
    }

    function isRebasePossible()
        external
        view
        virtual
        returns (
            bool possible,
            uint256 amountOut,
            uint256 amountInMax,
            address[] memory path,
            uint256 profitUSD,
            uint256 netProfitUSD,
            uint256 rebaseFeeUSD,
            uint256 minimumNetProfitUSD
        )
    {
        possible = false; //default value
        (amountOut, amountInMax, path, profitUSD, netProfitUSD, rebaseFeeUSD) = _getRebaseAmount(_pair);
        // check does enough allowance
        if (path[0] != address(0)) {
            minimumNetProfitUSD = _minimumNetProfitUSD;
            uint256 balance = IERC20(path[0]).allowance(_treasury, address(this));
            possible = path[0] != address(0) && balance >= amountInMax && netProfitUSD > minimumNetProfitUSD;
        }
    }

    function _getRebaseAmount(address pair)
        internal
        view
        returns (
            uint256 amountOut,
            uint256 amountInMax,
            address[] memory path,
            uint256 profitUSD,
            uint256 netProfitUSD,
            uint256 rebaseFeeUSD
        )
    {
        amountOut = 0;
        amountInMax = 0;
        path = new address[](2);
        path[0] = address(0);
        path[1] = address(0);
        FX memory fx;
        Reserves memory reserves;
        (reserves.reserve0, reserves.reserve1, ) = IPair(pair).getReserves();

        fx.fx0 = _getFXRateToUSD(_oracle0); //FX t0
        fx.fx1 = _getFXRateToUSD(_oracle1); // FX t1
        fx.fxNT = _getFXRateToUSD(_oracleNT); // FX native token

        reserves.reserve0USD = (reserves.reserve0 / 10**_oracle0Decimal) * fx.fx0; // reserves t0 in USD
        reserves.reserve1USD = (reserves.reserve1 / 10**_oracle1Decimal) * fx.fx1; // reserves t1 in USD
        // avarage kLast root => this amount of USD will be in LP
        // when token0 equal token1 by current market price
        uint256 averageUSD = Math.sqrt(reserves.reserve0USD * reserves.reserve1USD);

        rebaseFeeUSD = (((2908290000000000 * fx.fxNT) * 13) / 10) / 10**_oracleNTDecimal; //  BSC // 13/10 - 30% buffer for extra fee
        // dif0, dif1 - difference
        (uint256 dif0, uint256 dif1) = (reserves.reserve0USD > averageUSD)
            ? (
                ((reserves.reserve0USD - averageUSD) * 998500000000000000) / 1000000000000000000,
                ((averageUSD - reserves.reserve1USD) * 998500000000000000) / 1000000000000000000
            )
            : (
                ((averageUSD - reserves.reserve0USD) * 998500000000000000) / 1000000000000000000,
                ((reserves.reserve1USD - averageUSD) * 998500000000000000) / 1000000000000000000
            );

        profitUSD = dif0 > dif1 ? dif0 - dif1 : dif1 - dif0;
        netProfitUSD = 0;

        if (dif0 > dif1 && profitUSD > rebaseFeeUSD) {
            amountOut = (dif0 * 10**_oracle0Decimal) / fx.fx0;
            uint256 numerator = reserves.reserve1.mul(amountOut).mul(1000);
            uint256 denominator = reserves.reserve0.sub(amountOut).mul(997);
            amountInMax = (numerator / denominator).add(1);

            path[0] = _token1;
            path[1] = _token0;
            netProfitUSD = profitUSD - rebaseFeeUSD;
        }
        if (dif1 > dif0 && profitUSD > rebaseFeeUSD) {
            amountOut = (dif1 * 10**_oracle1Decimal) / fx.fx1;
            uint256 numerator = reserves.reserve0.mul(amountOut).mul(1000);
            uint256 denominator = reserves.reserve1.sub(amountOut).mul(997);
            amountInMax = (numerator / denominator).add(1);

            path[0] = _token0;
            path[1] = _token1;
            netProfitUSD = profitUSD - rebaseFeeUSD;
        }
    }

    function _getFXRateToUSD(address oracle) internal view returns (uint256 fxRate) {
        if (oracle == address(0)) {
            // if oracle for USD/USD return 1
            fxRate = 1; // for dev purposes fx == 1:1 when decimals == 0
        } else {
            fxRate = uint256(IDataFeed(oracle).latestAnswer());
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}

struct FX {
    uint256 fx0;
    uint256 fx1;
    uint256 fxNT;
}
struct Reserves {
    uint256 reserve0;
    uint256 reserve1;
    uint256 reserve0USD;
    uint256 reserve1USD;
}