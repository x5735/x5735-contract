// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

/**
 * @dev Interface of the TokensVesting contract.
 */
interface ITokensVesting {
    /**
     * @dev Returns the total amount of tokens in vesting plan.
     */
    function total() external view returns (uint256);

    /**
     * @dev Returns the total amount of private sale tokens in vesting plan.
     */
    function privateSale() external view returns (uint256);

    /**
     * @dev Returns the total amount of public sale tokens in vesting plan.
     */
    function publicSale() external view returns (uint256);

    /**
     * @dev Returns the total amount of team tokens in vesting plan.
     */
    function team() external view returns (uint256);

    /**
     * @dev Returns the total amount of advisor tokens in vesting plan.
     */
    function advisor() external view returns (uint256);

    /**
     * @dev Returns the total amount of liquidity tokens in vesting plan.
     */
    function liquidity() external view returns (uint256);

    /**
     * @dev Returns the total amount of incentives tokens in vesting plan.
     */
    function incentives() external view returns (uint256);

    /**
     * @dev Returns the total amount of marketing tokens in vesting plan.
     */
    function marketing() external view returns (uint256);

    /**
     * @dev Returns the total amount of reserve tokens in vesting plan.
     */
    function reserve() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of tokens.
     */
    function releasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of private sale tokens.
     */
    function privateSaleReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of public sale tokens.
     */
    function publicSaleReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of team tokens.
     */
    function teamReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of advisor tokens.
     */
    function advisorReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of liquidity tokens.
     */
    function liquidityReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of incentives tokens.
     */
    function incentivesReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of marketing tokens.
     */
    function marketingReleasable() external view returns (uint256);

    /**
     * @dev Returns the total releasable amount of reserve tokens.
     */
    function reserveReleasable() external view returns (uint256);

    /**
     * @dev Returns the total released amount of tokens.
     */
    function released() external view returns (uint256);

    /**
     * @dev Returns the total released amount of private sale tokens.
     */
    function privateSaleReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of public sale tokens.
     */
    function publicSaleReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of team tokens
     */
    function teamReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of advisor tokens.
     */
    function advisorReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of liquidity tokens.
     */
    function liquidityReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of incentives tokens.
     */
    function incentivesReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of marketing tokens.
     */
    function marketingReleased() external view returns (uint256);

    /**
     * @dev Returns the total released amount of reserve tokens.
     */
    function reserveReleased() external view returns (uint256);

    /**
     * @dev Unlocks all releasable amount of tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseAll() external;

    /**
     * @dev Unlocks all releasable amount of private sale tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releasePrivateSale() external;

    /**
     * @dev Unlocks all releasable amount of public sale tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releasePublicSale() external;

    /**
     * @dev Unlocks all releasable amount of team tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseTeam() external;

    /**
     * @dev Unlocks all releasable amount of advisor tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseAdvisor() external;

    /**
     * @dev Unlocks all releasable amount of liquidity tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseLiquidity() external;

    /**
     * @dev Unlocks all releasable amount of incentives tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseIncentives() external;

    /**
     * @dev Unlocks all releasable amount of marketing tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseMarketing() external;

    /**
     * @dev Unlocks all releasable amount of reserve tokens.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseReserve() external;

    /**
     * @dev Emitted when having amount of tokens are released.
     */
    event TokensReleased(address indexed beneficiary, uint256 amount);
}