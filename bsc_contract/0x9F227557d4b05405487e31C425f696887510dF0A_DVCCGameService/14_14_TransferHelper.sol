// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
  function safeApprove(address token, address to, uint256 value) internal {
    // bytes4(keccak256(bytes("approve(address,uint256)")));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeApprove: approve failed");
  }

  function safeTransfer(address token, address to, uint256 value) internal {
    // bytes4(keccak256(bytes("transfer(address,uint256)")));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeTransfer: transfer failed");
  }

  function safeTransferFrom(address token, address from, address to, uint256 value) internal {
    // bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
    require(
      success && (data.length == 0 || abi.decode(data, (bool))),
      "TransferHelper::transferFrom: transferFrom failed"
    );
  }

  function safeGasFeeClaim(address token, uint256 amount, address payer, string memory action) internal {
    // bytes4(keccak256(bytes("gasFeeClaim(uint256,address,string)")));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x202d2be5, amount, payer, action));
    require(
      success && (data.length == 0 || abi.decode(data, (bool))),
      "TransferHelper::transferFrom: transferFrom failed"
    );
  }

  function safeActivityFeeClaim(address token, uint256 amount, address payer, address receiver) internal {
    // bytes4(keccak256(bytes("activityClaim(uint256,address,address)")));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x1b8af900, amount, payer, receiver));
    require(
      success && (data.length == 0 || abi.decode(data, (bool))),
      "TransferHelper::transferFrom: transferFrom failed"
    );
  }
}