// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IToken.sol";

contract AirdropLock is ReentrancyGuard {
    address public tokenAddress;
    address public multSigAddress;
    address public signerAddress;
    uint256 public maxSupply = 11000000 * 10 ** 18; // 11%
    uint256 public totalSupply;
    uint256 public perRelease = 100000 * 10 ** 18;

    mapping(uint256 => bool) public usedNonces;

    constructor(address _multSigAddress, address _tokenAddress, address _signerAddress) public {
        multSigAddress = _multSigAddress;
        tokenAddress = _tokenAddress;
        signerAddress = _signerAddress;
    }

    modifier onlyMultSig() {
        require(msg.sender == multSigAddress, "MsgSender not is multSigAddress");
        _;
    }

    function claimReward(uint256 amount, uint256 nonce, bytes memory signature) external nonReentrant {
        require(!usedNonces[nonce], "Invalid nonce");
        
        usedNonces[nonce] = true;
        bytes32 message = prefixed(keccak256(abi.encodePacked(msg.sender, amount, this, nonce)));
        require(recoverSigner(message, signature) == signerAddress);

        uint256 bal = IERC20(tokenAddress).balanceOf(address(this));
        if(bal <= amount) _addTokenNum(amount);
        
        IToken(tokenAddress).transfer(msg.sender, amount);
    }
 
    function splitSignature(bytes memory sig) internal pure returns(uint8 v,bytes32 r,bytes32 s) {
        require(sig.length == 65);
        assembly{
            r:=mload(add(sig, 32))
            s:=mload(add(sig, 64))
            v:=byte(0,mload(add(sig, 96)))
        }
        return (v,r,s);
    }
 
    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns(address) {
        (uint8 v,bytes32 r,bytes32 s) = splitSignature(sig);
        return ecrecover(message,v,r,s);
    }
 
    function prefixed(bytes32 hash) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function setSignerAddress(address _signerAddress) public onlyMultSig {
        signerAddress = _signerAddress;
    }

    function setMultSig(address _multSigAddress) public onlyMultSig {
        multSigAddress = _multSigAddress;
    }

    function withdraw(address to, uint256 amount) public onlyMultSig {
        IToken(tokenAddress).transfer(to, amount);
    }

    function _addTokenNum(uint256 amount) private {
        if(totalSupply + amount > maxSupply) {
            amount = maxSupply - totalSupply;
            totalSupply = maxSupply;
        }

        require(totalSupply <= maxSupply, "totalSupply must <= maxSupply");
        IToken(tokenAddress).rewards(address(this), amount);
    }

    function addTokenNum(uint256 amount) public onlyMultSig {
        _addTokenNum(amount);
    }
}