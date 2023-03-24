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

//Jodi Usama Husain v1 for MAMA DeFi, to stabilize USDT_eEUR pool to reflect the real market and stablize pair.
contract Stabilize_Pair is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;
    using SafeMath for uint112;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    address private _pair;
    address private _token0;
    address private _token1;
    address private _oracle0;
    address private _oracle1;
    address private _oracleNT;
    address private _router;

    event Rebased(uint256 profitUSD, uint256 netProfitUSD);
    event Withdrawn(address indexed token, uint256 amount, address indexed to);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        address owner = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(UPGRADER_ROLE, owner);
        _grantRole(WITHDRAWER_ROLE, owner);

        setRouter(0x1D0EAa1038BA77270EF9698Ec41d26b0d83eb705);
        address USDT_eEUR_Pool = 0x3923ca1dd78c9F85F3137e48F53513B003dce49e;
        address eEUR = 0x735fa792e731a2e8F83F32eb539841b7B72e6d8f;
        address USDT = 0x55d398326f99059fF775485246999027B3197955;
        address oracle_USDT_USD = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
        address oracle_EUR_USD = 0x0bf79F617988C472DcA68ff41eFe1338955b9A80;
        address oracle_BNB_USD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

        setPair(USDT_eEUR_Pool, USDT, eEUR, oracle_USDT_USD, oracle_EUR_USD, oracle_BNB_USD);


    }

    function setRouter(address router) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(router != address(0));
        _router = router;
        return true;
    }

    function router() public view returns (address) {
        return _router;
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
        (_token0, _token1) = t0 == token0 ? (t0, t1) : (t1, t0);
        (_oracle0, _oracle1) = t0 == token0 ? (oracle0, oracle1) : (oracle1, oracle0);
        _pair = pair;
        _oracleNT = oracleNT;
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
            address
        )
    {
        return (_pair, _token0, _token1, _oracle0, _oracle1, _oracleNT);
    }

    function rebase() external whenNotPaused {
        // check does need to rebase
        (uint256 amountOut, uint256 amountInMax, address[] memory path) = _getRebaseAmount(_pair);
        require(path[0] != address(0), "Threshold not achieved");
        //
        uint256 balance = IERC20(path[0]).balanceOf(address(this));
        require(balance >= amountInMax, "Insufficient funds");
        // give allowance for router to do swap
        bool allowed = IERC20(path[0]).approve(_router, amountInMax);
        require(allowed, "Can't get allowance");
        IARYZE_Router02(_router).swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            address(this),
            block.timestamp + 3600
        );
    }

    function _getRebaseAmount(address pair)
        internal
        returns (
            uint256 amountOut,
            uint256 amountInMax,
            address[] memory path
        )
    {
        amountOut = 0;
        amountInMax = 0;
        path = new address[](2);
        path[0] = address(0);
        path[1] = address(0);
        (uint112 reserve0, uint112 reserve1, ) = IPair(pair).getReserves();
        uint256 fx0 = _getFXRateToUSD(_oracle0); //FX t0
        uint256 fx1 = _getFXRateToUSD(_oracle1); // FX t1
        uint256 fxNT = _getFXRateToUSD(_oracleNT); // FX native token
        uint256 reserve0USD = (reserve0 / 100000000) * fx0; // reserves t0 in USD
        uint256 reserve1USD = (reserve1 / 100000000) * fx1; // reserves t1 in USD
        // avarage kLast root => this amount of USD will be in LP
        // when token0 equal token1 by current market price
        uint256 averageUSD = Math.sqrt(reserve0USD * reserve1USD);
        uint256 rebaseFeeUSD = ((340000 * tx.gasprice * fxNT * 13) / 10) / 100000000; //  13/10 - 30% buffer for extra fee
        // tx price(bnb) * usd/bnb rate => fee in USD for this transaction
        // dif0, dif1 - difference
        (uint256 dif0, uint256 dif1) = (reserve0USD > averageUSD)
            ? (((reserve0USD - averageUSD) * 9985) / 10000, ((averageUSD - reserve1USD) * 9985) / 10000)
            : (((averageUSD - reserve0USD) * 9985) / 10000, ((reserve1USD - averageUSD) * 9985) / 10000);

        uint256 profitUSD = dif0 > dif1 ? dif0 - dif1 : dif1 - dif0;
        uint256 netProfitUSD = 0;
        if (dif0 > dif1 && profitUSD > rebaseFeeUSD) {
            amountOut = (dif0 * 100000000) / fx0;
            amountInMax = (dif0 * 100000000) / fx1; // _getAmountInMax(amountOut, reserve0, reserve1);
            path[0] = _token1;
            path[1] = _token0;
            netProfitUSD = profitUSD - rebaseFeeUSD;
        }
        if (dif1 > dif0 && profitUSD > rebaseFeeUSD) {
            amountOut = (dif1 * 100000000) / fx1;
            amountInMax = (dif1 * 100000000) / fx0; // _getAmountInMax(amountOut, reserve1, reserve0);
            path[0] = _token0;
            path[1] = _token1;
            netProfitUSD = profitUSD - rebaseFeeUSD;
        }
        emit Rebased(profitUSD, netProfitUSD);
    }

    function _getFXRateToUSD(address oracle) internal view returns (uint256 fxRate) {
        if (oracle == address(0)) {
            fxRate = 100000000; // for dev purposes fx == 1:1
        } else {
            fxRate = uint256(IDataFeed(oracle).latestAnswer());
        }
    }

    function withdraw(address token, uint256 amount) external onlyRole(WITHDRAWER_ROLE) returns (bool transferred) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient funds");
        transferred = IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(token, amount, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}