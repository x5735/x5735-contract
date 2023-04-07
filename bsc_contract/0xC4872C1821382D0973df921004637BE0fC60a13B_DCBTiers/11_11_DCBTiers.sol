// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol";

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IDCBMasterChef.sol";
import "../interfaces/IDCBStaking.sol";
import "../interfaces/IDCBVault.sol";
import "../interfaces/IDCBLiqLocker.sol";

contract DCBTiers is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    /**
     *
     * @dev Tier struct
     *
     *
     * @param {minLimit} Minimum amount of dcb to be staked to join tier
     * @param {maxLimit} Maximum amount of dcb to be staked to join tier
     * @param {refundFee} Refund fee % for this tier
     *
     */
    struct Tier {
        uint256 minLimit;
        uint256 maxLimit;
        uint256 refundFee;
    }

    Tier[] public tierInfo; //Tier storage

    address public dcbTokenAddress; //DCB token instance

    IDCBMasterChef public legacyStakingContract; //Legacy staking contract instance
    IDCBMasterChef public compoundStakingContract; // Compound Staking contract instance
    IDCBStaking public multiAssetStakingContract; //Multi asset Staking contract instance
    IDCBVault public compounderContract; //Staking contract instance
    IDCBLiqLocker public liquidityLocker; //Liquidity locker contract

    event TierAdded(uint256 _minLimit, uint256 _maxLimit, uint256 _refundFee);
    event TierSet(uint256 tierId, uint256 _minLimit, uint256 _maxLimit, uint256 _refundFee);
    event LegacyStakingSet(address _stakingContract);
    event CompoundStakingSet(address _stakingContract);
    event MultiAssetSet(address _stakingContract);
    event CompounderSet(address _stakingContract);
    event LiquidityLockerSet(address _stakingContract);
    event TokenSet(address _token);

    /**
     *
     * @dev add new tier, only available for owner
     *
     */
    function addTier(uint256 _minLimit, uint256 _maxLimit, uint256 _refundFee) external onlyOwner returns (bool) {
        tierInfo.push(Tier({ minLimit: _minLimit, maxLimit: _maxLimit, refundFee: _refundFee }));
        emit TierAdded(_minLimit, _maxLimit, _refundFee);
        return true;
    }

    /**
     *
     * @dev update a given tier
     *
     */
    function setTier(
        uint256 tierId,
        uint256 _minLimit,
        uint256 _maxLimit,
        uint256 _refundFee
    )
        external
        onlyOwner
        returns (bool)
    {
        require(tierId < tierInfo.length, "Invalid tier Id");

        tierInfo[tierId].minLimit = _minLimit;
        tierInfo[tierId].maxLimit = _maxLimit;
        tierInfo[tierId].refundFee = _refundFee;
        emit TierSet(tierId, _minLimit, _maxLimit, _refundFee);

        return true;
    }

    /**
     *
     * @dev set address of legacy staking contract
     *
     */
    function setLegacyStakingContract(address _stakingContract) external onlyOwner {
        legacyStakingContract = IDCBMasterChef(_stakingContract);
        emit LegacyStakingSet(_stakingContract);
    }

    /**
     *
     * @dev set address of compound staking contract
     *
     */
    function setCompoundingStakingContract(address _stakingContract) external onlyOwner {
        compoundStakingContract = IDCBMasterChef(_stakingContract);
        emit CompoundStakingSet(_stakingContract);
    }

    /**
     *
     * @dev set address of compound staking contract
     *
     */
    function setMultiAssetStakingContract(address _stakingContract) external onlyOwner {
        multiAssetStakingContract = IDCBStaking(_stakingContract);
        emit MultiAssetSet(_stakingContract);
    }

    /**
     *
     * @dev set address of compounder contract
     *
     */
    function setCompounderContract(address _compounder) external onlyOwner {
        compounderContract = IDCBVault(_compounder);
        emit CompounderSet(_compounder);
    }

    /**
     *
     * @dev set address of Liquidity locker contract
     *
     */
    function setLiqLockerContract(address _liqContract) external onlyOwner {
        liquidityLocker = IDCBLiqLocker(_liqContract);
        emit LiquidityLockerSet(_liqContract);
    }

    /**
     *
     * @dev set address of dcb token contract
     *
     */
    function setDCBTokenAddress(address _token) external onlyOwner {
        dcbTokenAddress = _token;
        emit TokenSet(_token);
    }

    /**
     *
     * @dev get total number of the tiers
     *
     * @return len length of the pools
     *
     */
    function getTiersLength() external view returns (uint256) {
        return tierInfo.length;
    }

    /**
     *
     * @dev get info of all tiers
     *
     * @return {Tier[]} tier info struct
     *
     */
    function getTiers() external view returns (Tier[] memory) {
        return tierInfo;
    }

    /**
     *
     * @dev Get tier of a user
     * Total deposit should be greater than or equal to minimum limit or
     * less than maximum limit. If equal to max limit, user will be given
     * next tier
     *
     * @param addr Address of the user
     *
     * @return flag Whether user belongs to any bracket or not
     * @return pos To which bracket does the user belong
     *
     */

    function getTierOfUser(address addr) external view returns (bool flag, uint256 pos, uint256 multiplier) {
        uint256 len = tierInfo.length;
        uint256 totalDeposit = getTotalDeposit(addr);
        multiplier = 1;

        for (uint256 i = 0; i < len; i++) {
            if (totalDeposit >= tierInfo[i].minLimit && totalDeposit < tierInfo[i].maxLimit) {
                pos = i;
                flag = true;
                break;
            }
        }

        // compounding effect for final bracket
        if (!flag && totalDeposit > tierInfo[len - 1].maxLimit) {
            pos = len - 1;
            flag = true;
            // multiplier is the users total deposit divided by the
            // minimum limit in the tier. For example Diamond tier is
            // 80,0000+ DCB. The max limit of the tier should be set
            // 159,999 DCB and when the limit is passed the compounding
            // effect will be used to find the number of tickets e.g 2
            // for 160,000
            multiplier = totalDeposit / (tierInfo[len - 1].minLimit);
        }

        return (flag, pos, multiplier);
    }

    function initialize(
        address _legacyStakingContract,
        address _compoundStakingContract,
        address _multiAssetStakingContract,
        address _vault,
        address _liquidityLocker,
        address _token
    )
        public
        initializer
    {
        __Ownable_init();

        legacyStakingContract = IDCBMasterChef(_legacyStakingContract);
        compoundStakingContract = IDCBMasterChef(_compoundStakingContract);
        multiAssetStakingContract = IDCBStaking(_multiAssetStakingContract);
        compounderContract = IDCBVault(_vault);
        liquidityLocker = IDCBLiqLocker(_liquidityLocker);
        dcbTokenAddress = _token;
    }

    /**
     *
     * @dev Get total amount of dcb staked by a user
     *
     * @param addr Address of the user
     *
     * @return amount Total amount of dcb staked
     */

    function getTotalDeposit(address addr) public view returns (uint256 amount) {
        uint256 len = legacyStakingContract.poolLength();
        uint256 tempAmt;

        for (uint256 i = 0; i < len; i++) {
            (tempAmt,,,,) = legacyStakingContract.users(i, addr);
            amount = amount.add(tempAmt);
        }

        len = compoundStakingContract.poolLength();

        for (uint256 i = 0; i < len; i++) {
            (,,,,,,,,, address token) = compoundStakingContract.poolInfo(i);

            if (token == dcbTokenAddress) {
                (,, tempAmt,) = compounderContract.users(i, addr);
                amount = amount.add(tempAmt);
            }
        }

        len = multiAssetStakingContract.poolLength();
        IDCBStaking.PoolToken memory inputToken;

        for (uint256 i = 0; i < len; i++) {
            (,,,,, inputToken,,,,,) = multiAssetStakingContract.poolInfo(i);

            if (inputToken.addr == dcbTokenAddress) {
                (tempAmt,,,,) = multiAssetStakingContract.users(i, addr);
                amount = amount.add(tempAmt);
            }
        }

        len = liquidityLocker.poolLength();
        address _pair;

        for (uint256 i = 0; i < len; i++) {
            (,,,,,,,, _pair,) = liquidityLocker.pools(i);
            IUniswapV2Pair pair = IUniswapV2Pair(_pair);

            if (pair.token0() == dcbTokenAddress) {
                (uint256 lpTokens,,,,) = liquidityLocker.users(i, addr);
                (tempAmt,) = getTokenAmounts(lpTokens, pair);
                amount = amount.add(tempAmt * 2);
            } else if (pair.token1() == dcbTokenAddress) {
                (uint256 lpTokens,,,,) = liquidityLocker.users(i, addr);
                (, tempAmt) = getTokenAmounts(lpTokens, pair);
                amount = amount.add(tempAmt * 2);
            }
        }
    }

    function getTokenAmounts(
        uint256 _amount,
        IUniswapV2Pair _pair
    )
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 reserve0, uint256 reserve1,) = _pair.getReserves();

        amount0 = _amount.mul(reserve0).div(_pair.totalSupply());
        amount1 = _amount.mul(reserve1).div(_pair.totalSupply());
    }
}