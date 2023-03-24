// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import {IConnext} from "@connext/nxtp-contracts/contracts/core/connext/interfaces/IConnext.sol";
import {IXReceiver} from "@connext/nxtp-contracts/contracts/core/connext/interfaces/IXReceiver.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
}

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

interface Vault {
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);
}

/**
 * @title ConxLbpSwapTargetV1
 * @notice A contract that can receive funds from the Connext bridge and Balancer vault parms to perform an LBP swap.
 */
contract ConxLbpSwapTargetV1 is IXReceiver {
    IConnext public immutable connext;
    address public immutable vaultAddress;

    constructor(IConnext _connext, address _vaultAddress) {
        connext = _connext;
        require(_vaultAddress != address(0), "vault cannot be address(0)");
        vaultAddress = _vaultAddress;
    }

    /**
     * @notice The receiver function as required by the IXReceiver interface.
     * @dev The Connext bridge contract will call this function.
     */
    function xReceive(
        bytes32 /* _transferId */,
        uint256 _amount, // must be amount in bridge asset less fees
        address _asset,
        address /* _originSender */,
        uint32 /* _origin */,
        bytes memory _callData
    ) external returns (bytes memory) {
        (SingleSwap memory singleSwap, FundManagement memory funds, uint256 limit, uint256 deadline) = abi.decode(
            _callData,
            (SingleSwap, FundManagement, uint256, uint256)
        );

        if (singleSwap.kind == SwapKind.GIVEN_IN) {
            TransferHelper.safeApprove(singleSwap.assetIn, vaultAddress, singleSwap.amount);
        } else {
            TransferHelper.safeApprove(singleSwap.assetIn, vaultAddress, _amount);
        }

        // perform swap
        try Vault(vaultAddress).swap(singleSwap, funds, limit, deadline) returns (uint _swappedAmount) {} catch Error(
            string memory reason
        ) {
            TransferHelper.safeTransfer(_asset, funds.recipient, _amount);
        }
        return "";
    }
}