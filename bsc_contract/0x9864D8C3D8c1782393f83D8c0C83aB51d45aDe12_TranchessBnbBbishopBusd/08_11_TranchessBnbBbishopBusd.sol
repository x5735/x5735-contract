// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DefiiWithCustomExit} from "../DefiiWithCustomExit.sol";

contract TranchessBnbBbishopBusd is DefiiWithCustomExit {
    IERC20 constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 constant CHESS = IERC20(0x20de22029ab63cf9A7Cf5fEB2b737Ca1eE4c82A6);
    IERC20 constant lpToken =
        IERC20(0x3F586aA29C61488f25748911be3c52246c744fc2);

    IStableSwap constant pool =
        IStableSwap(0x999DB223F0807B164b783eE33d48782cc6E06742);
    IFund constant fund = IFund(0x2f40c245c66C5219e0615571a526C93883B456BB);
    IClaimRewards constant shareStaking =
        IClaimRewards(0xFa7b73009d635b0AB069cBe99C5a5D498F701c76);
    IClaimRewards constant liquidityGauge =
        IClaimRewards(0x3F586aA29C61488f25748911be3c52246c744fc2);

    uint256 constant TRANCHE_B = 1;

    function hasAllocation() public view override returns (bool) {
        return lpToken.balanceOf(address(this)) > 0;
    }

    function exitParams(uint256 slippage) public view returns (bytes memory) {
        require(slippage > 800, "Slippage must be >800, (>80%)");
        require(slippage < 1200, "Slippage must be <1200, (<120%)");

        uint256 minPrice = (((pool.getOraclePrice() * pool.getCurrentPrice()) /
            1e36) * slippage) / 1000;

        return abi.encode(minPrice);
    }

    function _enter() internal override {
        BUSD.transfer(address(pool), BUSD.balanceOf(address(this)));
        pool.addLiquidity(fund.getRebalanceSize(), address(this));
    }

    function _exitWithParams(bytes memory params) internal override {
        uint256 minPrice = abi.decode(params, (uint256));

        uint256 version = fund.getRebalanceSize();

        (uint256 baseOut, ) = pool.removeLiquidity(
            version,
            lpToken.balanceOf(address(this)),
            0,
            0
        );

        fund.trancheTransfer(TRANCHE_B, address(pool), baseOut, version);
        uint256 realQuoteOut = pool.sell(
            version,
            pool.getQuoteOut(baseOut),
            address(this),
            bytes("")
        );

        uint256 minQuoteOut = baseOut * minPrice;
        require(realQuoteOut >= minQuoteOut, "Slippage BISHOP -> BUSD");

        _claim();
        _claimIncentive(CHESS);
    }

    function _exit() internal override {
        _exitWithParams(exitParams(995));
    }

    function _harvest() internal override {
        _claim();
        _claimIncentive(CHESS);
    }

    function _withdrawFunds() internal override {
        _withdrawERC20(BUSD);
    }

    function _claim() internal {
        shareStaking.claimRewards(address(this));
        liquidityGauge.claimRewards(address(this));
    }
}

interface IStableSwap {
    function addLiquidity(
        uint256 version,
        address recipient
    ) external returns (uint256 lpOut);

    function removeLiquidity(
        uint256 version,
        uint256 lpIn,
        uint256 minBaseOut,
        uint256 minQuoteOut
    ) external returns (uint256 baseOut, uint256 quoteOut);

    function sell(
        uint256 version,
        uint256 quoteOut,
        address recipient,
        bytes calldata data
    ) external returns (uint256 realQuoteOut);

    function getQuoteOut(
        uint256 baseIn
    ) external view returns (uint256 quoteOut);

    function getOraclePrice() external view returns (uint256);

    function getCurrentPrice() external view returns (uint256);

    function currentVersion() external returns (uint256);
}

interface IClaimRewards {
    function claimRewards(address account) external;
}

interface IFund {
    function getRebalanceSize() external returns (uint256);

    function trancheTransfer(
        uint256 tranche,
        address recipient,
        uint256 amount,
        uint256 version
    ) external;
}