// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;

enum DataSource {
    Campaign,
    SuperCerts,
    Governance,
    Referral,
    Proposal,
    MarketPlace,
    SuperFarm,
    EggPool,
    Swap
}

enum DataAction {
    Buy,
    Refund,
    ClaimCerts,
    ClaimTokens,
    ClaimTeamTokens,
    List,
    Unlist,
    AddLp,
    RemoveLp,
    Rebate,
    Revenue,
    Swap
}

interface IDataLog {
    
    function log(address fromContract, address fromUser, uint source, uint action, uint data1, uint data2) external;

}