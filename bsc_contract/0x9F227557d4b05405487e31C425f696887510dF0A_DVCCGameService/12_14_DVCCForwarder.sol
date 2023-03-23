// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Revision: 2023-1-13
// version 1.0.0

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @dev - Module will be updated to more complete after some product iterations
contract DVCCForwarder is EIP712, AccessControl {
  using ECDSA for bytes32;

  bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

  struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
  }

  bytes32 private constant _TYPEHASH =
    keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)");

  mapping(address => uint256) private _nonces;

  event ForwardStatus(bool status, bytes msg);

  constructor() EIP712("DVCCForwarder", "0.0.1") {
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function getNonce(address from) public view returns (uint256) {
    return _nonces[from];
  }

  function verify(ForwardRequest calldata req, bytes calldata signature) public view returns (bool) {
    address signer = _hashTypedDataV4(
      keccak256(abi.encode(_TYPEHASH, req.from, req.to, req.value, req.gas, req.nonce, keccak256(req.data)))
    ).recover(signature);
    return _nonces[req.from] == req.nonce && signer == req.from;
  }

  function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
    // If the _res length is less than 68, then the transaction failed silently (without a revert message)
    if (_returnData.length < 68) return "Transaction reverted silently";

    assembly {
      // Slice the sighash.
      _returnData := add(_returnData, 0x04)
    }
    return abi.decode(_returnData, (string)); // All that remains is the revert string
  }

  function execute(
    ForwardRequest calldata req,
    bytes calldata signature
  ) public payable onlyRole(RELAYER_ROLE) returns (bool, bytes memory) {
    require(verify(req, signature), "DVCCForwarder: signature does not match request");
    _nonces[req.from] = req.nonce + 1;

    (bool success, bytes memory returndata) = req.to.call{gas: req.gas, value: req.value}(
      abi.encodePacked(req.data, req.from)
    );

    // Validate that the relayer has sent enough gas for the call.
    // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
    if (gasleft() <= req.gas / 63) {
      assembly {
        invalid()
      }
    }
    if (success) {
      emit ForwardStatus(success, "");
    } else {
      emit ForwardStatus(success, returndata);
    }

    return (success, returndata);
  }
}