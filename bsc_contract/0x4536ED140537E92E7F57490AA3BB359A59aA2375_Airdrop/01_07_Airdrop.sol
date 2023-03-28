// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Token.sol";


contract Airdrop is Ownable {
    using SafeMath for uint;

    address public tokenAddr;
    uint256 public amount;
    address private contractAddr = address(this);

    event EtherTransfer(address beneficiary, uint amount);
    
   
    function dropTokens(address _tokenAddr, address[] memory _recipients, uint256[] memory _amount) public returns (bool) {
        tokenAddr = _tokenAddr;
        for (uint i = 0; i < _recipients.length; i++) {
            //_amount[i] = _amount[i] * 10**18;
            require(_recipients[i] != address(0));
            require(Token(tokenAddr).allowance(msg.sender, contractAddr) > 0, "fail");
            require(Token(tokenAddr).transferFrom(msg.sender, _recipients[i], _amount[i]), "no transfer");
        }

        return true;
    }
}