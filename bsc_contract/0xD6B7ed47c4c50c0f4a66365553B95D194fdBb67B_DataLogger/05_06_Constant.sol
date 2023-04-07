// SPDX-License-Identifier: BUSL-1.1


pragma solidity 0.8.15;

library Constant {

    address public constant ZERO_ADDRESS                        = address(0);
    uint    public constant E18                                 = 1e18;
    uint    public constant PCNT_100                            = 1e18;
    uint    public constant PCNT_50                             = 5e17;
    
    // SaleTypes
    uint    public constant TYPE_IDO                            = 0;
    uint    public constant TYPE_OTC                            = 1;
    uint    public constant TYPE_NFT                            = 2;
       
}