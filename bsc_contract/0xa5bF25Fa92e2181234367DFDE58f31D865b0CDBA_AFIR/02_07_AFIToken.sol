// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./NewERC20.sol";

abstract contract AFIToken is ERC20 {
    function mint(address _to, uint256 _amount) public virtual;
}