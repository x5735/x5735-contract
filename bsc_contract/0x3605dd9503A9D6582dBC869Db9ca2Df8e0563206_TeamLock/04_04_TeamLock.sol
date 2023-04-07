// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interfaces/IToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TeamLock is Ownable {
   
    address public tokenAddress;
    address public multSigAddress;
    uint256 public teamTotal = 9500000 * 10 ** 18; // 9.5%
    uint256 public adviserTotal = 1000000 * 10 ** 18; // 1%
    uint256 public totalSupply;
    uint256 public startBlock = 0;
    uint256 public dayBlockNum = 10;//28800;
    uint256 public monBlockNum = dayBlockNum * 120;

    struct UserLock {
        uint256 lockTotal;
        uint256 claimed;
        uint256 perReleaseMonth;
        uint256 nextReleaseBlock;
    }

    mapping(address => UserLock) public userLocks;

    modifier onlyMultSig() {
        require(multSigAddress == msg.sender, "Not permisson");
        _;
    }

    constructor(address _tokenAddress, address _multSigAddress) public {
        tokenAddress = _tokenAddress;
        multSigAddress = _multSigAddress;
    }

    function addTeamLock(address account, uint256 ratio) public onlyOwner {
        if(startBlock == 0) startBlock = block.number;
        
        UserLock storage userLock = userLocks[account];
        userLock.lockTotal = teamTotal * ratio / 10000;
        userLock.nextReleaseBlock = startBlock + 12 * monBlockNum + monBlockNum;
        userLock.perReleaseMonth = userLock.lockTotal / 12;
    }

    function changeAccount(address oldAddr, address newAddr) public onlyMultSig {
        UserLock storage userLock = userLocks[oldAddr];
        userLocks[newAddr] = userLock;
        delete userLocks[oldAddr];
    }

    function addAdviserLock(address account, uint256 ratio) public onlyOwner {
        if(startBlock == 0) startBlock = block.number;

        UserLock storage userLock = userLocks[account];
        userLock.lockTotal = adviserTotal * ratio / 10000;
        userLock.nextReleaseBlock = startBlock + 12 * monBlockNum + monBlockNum;
        userLock.perReleaseMonth = userLock.lockTotal / 10;
    }

    function withdraw(address account) public onlyMultSig {
        UserLock storage userLock = userLocks[account];
        require(userLock.lockTotal > 0, "User not exists");
        require(userLock.claimed < userLock.lockTotal, "Lock release finish");
        require(block.number > userLock.nextReleaseBlock, "Lock time err");

        uint256 diffBlock = block.number - userLock.nextReleaseBlock;
        uint256 month = diffBlock / monBlockNum + 1;
        uint256 release = month * userLock.perReleaseMonth;
        if(userLock.claimed + release > userLock.lockTotal) {
            release = userLock.lockTotal - userLock.claimed;
        }

        userLock.claimed += release;
        userLock.nextReleaseBlock = block.number + monBlockNum - diffBlock % monBlockNum;

        totalSupply += release;
        require(totalSupply <= teamTotal + adviserTotal, "totalSupply must <= teamTotal + adviserTotal");

        IToken(tokenAddress).rewards(address(this), release);
        IToken(tokenAddress).transfer(msg.sender, release);
    }

    function penddingRelease(address account) public view returns (uint256) {
        UserLock memory userLock = userLocks[account];
        if(block.number < userLock.nextReleaseBlock) {
            return 0;
        }

        if(userLock.claimed >= userLock.lockTotal) {
            return 0;
        }

        uint256 diffBlock = block.number - userLock.nextReleaseBlock;
        uint256 month = diffBlock / monBlockNum + 1;

        uint256 release = month * userLock.perReleaseMonth;
        if(userLock.claimed + release > userLock.lockTotal) {
            release = userLock.lockTotal - userLock.claimed;
        }

        return release;
    }
}