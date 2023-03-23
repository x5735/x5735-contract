pragma solidity 0.8.17;
// SPDX-License-Identifier: MIT

interface ISpotV1 {

    struct Swap {
        address[] path;
        uint outMin;
    }

    struct Log {
        uint timestamp;
        uint blocknumber;
        uint8 operationType; // 0 - deposit, 1 - withdrawal, 2 - restake
        address token; // deposit or withdrawal token
        uint tokenAmount;
        uint lpAmount; // amount of LP deposited or withdrawn
        uint lpToken0Amount;
        uint lpToken1Amount;
    }
    
    function init(
        address _wrapper,
        address _pool,
        address _router,
        address _stakingToken,
        address _rewardToken,
        uint _poolIndex,
        uint _ownerId,
        address _registry,
        address factory
    ) external;

    function deposit(
        uint amount,
        Swap memory swap0,
        Swap memory swap1,
        Swap memory swapReward0,
        Swap memory swapReward1,
        uint deadline
    ) external payable;

    function withdraw(
        uint amountToBurn,
        Swap memory swap0,
        Swap memory swap1,
        Swap memory swapReward0,
        Swap memory swapReward1,
        uint deadline
    ) external;

    function restake(
        Swap memory swapReward0,
        Swap memory swapReward1,
        uint deadline
    ) external;

}