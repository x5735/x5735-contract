// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interfaces/IToken.sol";

contract PrivateSale {
    address public tokenAddress;
    address public multSigAddress;

    uint256 public maxSupply = 6500000 * 10 ** 18; // 6.5%
    uint256 public totalSupply;

    constructor(address _multSigAddress, address _tokenAddress) public {
        multSigAddress = _multSigAddress;
        tokenAddress = _tokenAddress;
    }

    modifier onlyMultSig() {
        require(msg.sender == multSigAddress, "MsgSender not is multSigAddress");
        _;
    }

    function setMultSig(address _multSigAddress) public onlyMultSig {
        multSigAddress = _multSigAddress;
    }

    function withdraw(address to, uint256 amount) public onlyMultSig {
        totalSupply += amount;
        require(totalSupply <= maxSupply, "totalSupply must <= maxSupply");

        IToken(tokenAddress).rewards(address(this), amount);
        IToken(tokenAddress).transfer(to, amount);
    }
}