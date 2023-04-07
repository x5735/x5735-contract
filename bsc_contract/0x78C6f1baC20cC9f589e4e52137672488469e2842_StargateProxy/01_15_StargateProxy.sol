// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IStargateProxy.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateFactory.sol";
import "./interfaces/IStargatePool.sol";
import "./interfaces/IStargateProxyReceiver.sol";
import "./libraries/SwapUtils.sol";

contract StargateProxy is Ownable, IStargateReceiver, IStargateProxy {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable router;
    address public immutable factory;
    mapping(uint16 => address) public dstAddress;

    constructor(address _router) {
        router = _router;
        factory = IStargateRouter(_router).factory();
    }

    function estimateFee(
        uint16 dstChainId,
        address dstCallTo,
        bytes calldata dstCallData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(from, dstCallTo, dstCallData),
            IStargateRouter.lzTxObj(dstGasForCall, dstNativeAmount, abi.encodePacked(from))
        );
        return fee;
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transferNative(uint256 amount, TransferParams calldata params) external payable {
        if (params.swapTo != address(0)) {
            SwapUtils.swapNative(amount, params.swapTo, params.swapData);
        }
        _transfer(params, payable(msg.sender), msg.value - amount);

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).sendValue(balance);
        }
    }

    function transferERC20(
        address token,
        uint256 amount,
        TransferParams calldata params
    ) external payable {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        if (params.swapTo != address(0)) {
            SwapUtils.swapERC20(token, amount, params.swapTo, params.swapData, true, msg.sender);
        }
        _transfer(params, payable(msg.sender), msg.value);
    }

    function _transfer(
        TransferParams calldata params,
        address payable from,
        uint256 fee
    ) internal {
        address dst = dstAddress[params.dstChainId];
        if (dst == address(0)) revert DstChainNotFound(params.dstChainId);

        address pool = IStargateFactory(factory).getPool(params.poolId);
        if (pool == address(0)) revert PoolNotFound(params.poolId);

        address token = IStargatePool(pool).token();
        IERC20(token).approve(router, params.amount);
        IStargateRouter(router).swap{value: fee}(
            params.dstChainId,
            params.poolId,
            params.dstPoolId,
            from,
            params.amount,
            params.dstMinAmount,
            IStargateRouter.lzTxObj(params.dstGasForCall, params.dstNativeAmount, abi.encodePacked(from)),
            abi.encodePacked(dst),
            abi.encodePacked(from, params.dstCallTo, params.dstCallData)
        );

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(msg.sender, balance);
        }
    }

    //---------------------------------------------------------------------------
    // RECEIVER FUNCTIONS
    function sgReceive(
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external {
        if (msg.sender != router) revert Forbidden();

        address srcFrom = address(bytes20(payload[0:20]));
        address to = address(bytes20(payload[20:40]));
        if (to != address(0)) {
            IERC20(token).safeTransfer(to, amountLD);
            try IStargateProxyReceiver(to).sgProxyReceive(srcFrom, token, amountLD, payload[40:]) {} catch (
                bytes memory reason
            ) {
                try IStargateProxyReceiver(to).onReceiveERC20(token, srcFrom, amountLD) {} catch {}
                emit CallFailure(srcFrom, to, payload[40:], reason);
            }
        }

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(to == address(0) ? srcFrom : to, balance);
            if (to != address(0)) {
                try IStargateProxyReceiver(to).onReceiveERC20(token, srcFrom, balance) {} catch {}
            }
        }

        balance = address(this).balance;
        if (balance > 0) {
            srcFrom.call{value: balance}("");
        }

        emit SGReceive(srcChainId, srcAddress, nonce, token, amountLD, payload);
    }
}