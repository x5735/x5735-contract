// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IGenesisBond {
    // Info for bond holder
    struct Bond {
        uint256 payout; // payout token remaining to be paid
        uint256 vesting; // seconds left to vest
        uint256 lastBlockTimestamp; // Last interaction
        uint256 truePricePaid; // Price paid (principal tokens per payout token) in ten-millionths - 4000000 = 0.4
    }

    function initialize(
        address[6] calldata _config,
            /* address _customTreasury,
            address _principalToken,
            address _treasury,
            address _subsidyRouter,
            address _bondNft,
            address _initialOwner, */
        uint[] memory _tierCeilings, 
        uint[] memory _fees,
        bool _feeInPayout
    ) external;

    function redeem(
        uint256 bondId
    ) external returns (uint256);

    function percentVestedFor(
        uint256 bondId
    ) external view returns (uint256);

    function pendingPayoutFor(
        uint256 bondId
    ) external view returns (uint256);

    function pendingVesting(
        uint256 bondId
    ) external view returns (uint256);

    function payoutToken() external view returns (address);

    function bondInfo(uint256 bondId) external view returns (Bond memory);
}