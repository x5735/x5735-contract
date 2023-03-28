// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract BWCAirdrop is Ownable {

    uint public nonce;

    function ERC721BulkTransfer(uint _startNonce, address vault, IERC721 _token, address[] memory _users, uint[] memory _tokenIds) external onlyOwner {
        require(_startNonce > nonce, "already done, nonce expired");
        require(_users.length > 0 && _users.length == _tokenIds.length, "illegal length");
        if (vault == address(0)) {
            vault = msg.sender;
        }
        for (uint i = 0; i < _users.length; i ++) {
            _token.safeTransferFrom(vault, _users[i], _tokenIds[i]);
        }
        nonce = _startNonce + _users.length - 1;
    }
}