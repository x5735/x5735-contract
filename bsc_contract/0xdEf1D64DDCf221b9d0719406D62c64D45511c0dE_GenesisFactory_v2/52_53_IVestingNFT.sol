// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

/**
 * @title Non-Fungible Token Vesting Standard
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IVestingNFT {
   /**
     * @dev Returns the vested payout of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function vestedPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @dev Returns the payout of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function pendingPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @dev Returns remaining vesting in seconds of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function pendingVesting(uint256 tokenId) external view returns (uint256 vestingSeconds);

    /**
     * @dev Returns the payout token of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function payoutToken(uint256 tokenId) external view returns (address token);

    /**
     * @dev claims vested asset of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function claim(uint256 tokenId) external;
}