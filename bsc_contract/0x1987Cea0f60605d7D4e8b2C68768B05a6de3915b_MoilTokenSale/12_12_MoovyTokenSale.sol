// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Moovy.sol";

contract MoilTokenSale is Ownable {

    using SafeERC20 for IERC20;

    struct AccountData {
        uint256 balance;
        uint256 unlockedBalance;
        uint256 index;
    }

    struct AccountPayload {
        address account;
        uint256 balance;
    }

    struct RoundData {
        address[] accountList;
        mapping(address => AccountData) accounts;
        uint256 cliff;
        uint256 vestingPeriod;
        uint256 initialUnlock;
    }

    enum RoundType {
        Seed, Private, IGO
    }

    uint256 constant private MAX_BPS = 10000;
    mapping(RoundType => RoundData) roundData;

    Moil immutable public token;
    IERC20 immutable public payToken;
    uint256 immutable public pricePerToken;
    uint256 immutable public tokenSaleSupply;
    uint256 immutable public maxIGOSupply;

    bool public isIGOStarted;
    uint256 public tokenSold;

    uint256 private _tokenSaleEndTimestamp;

    event StartIGO();
    event EndIGO();
    event Buy(address buyer, uint256 value);
    event Claim(RoundType round, address claimer, uint256 claimedValue);

    constructor(IERC20 _payToken, Moil _token) {
        token = _token;
        payToken = _payToken;
        pricePerToken = 37 ether / 100;
        tokenSaleSupply = 27_000_000 ether;
        maxIGOSupply = 1_000_000 ether;

        roundData[RoundType.Seed].cliff = 2 * 30 days;
        roundData[RoundType.Seed].vestingPeriod = 8 * 30 days;
        roundData[RoundType.Seed].initialUnlock = 500;

        roundData[RoundType.Private].cliff = 1 * 30 days;
        roundData[RoundType.Private].vestingPeriod = 8 * 30 days;
        roundData[RoundType.Private].initialUnlock = 500;

        roundData[RoundType.IGO].cliff = 0 * 30 days;
        roundData[RoundType.IGO].vestingPeriod = 5 * 30 days;
        roundData[RoundType.IGO].initialUnlock = 4000;

    }

    function startIGO() external onlyOwner {
        isIGOStarted = true;
        emit StartIGO();
    }

    function buy(uint256 value) external {
        require(isIGOStarted, "[buy]: IGO is not started");
        require(_tokenSaleEndTimestamp == 0, "[buy]: token sale is ended");
        require(tokenSold + value <= maxIGOSupply, "[buy]: max token supply exceeded");

        RoundData storage round = roundData[RoundType.IGO];
        address sender = msg.sender;

        uint256 requiredValue = value * pricePerToken / 1 ether;

        payToken.transferFrom(sender, owner(), requiredValue);

        if (round.accounts[sender].balance == 0) {
            round.accounts[sender].index = round.accountList.length;
            round.accountList.push(sender);
        }

        round.accounts[sender].balance += value;
        tokenSold += value;

        emit Buy(sender, value);

        if (tokenSold == maxIGOSupply) {
            _tokenSaleEndTimestamp = block.timestamp;
            emit EndIGO();
        }

    }

    function addParticipants(RoundType _round, AccountPayload[] calldata accounts) external onlyOwner {
        require(_tokenSaleEndTimestamp == 0, "[addParticipants]: token sale is ended");
        require(_round == RoundType.Seed || _round == RoundType.Private, "[addParticipants]: you can add only to seed or private round");
        RoundData storage round = roundData[_round];

        for (uint256 i; i < accounts.length;) {
            round.accounts[accounts[i].account].balance = accounts[i].balance;
            round.accounts[accounts[i].account].index = round.accountList.length;
            round.accountList.push(accounts[i].account);
        unchecked {
            i++;
        }
        }
    }

    function claim(RoundType round) external {
        address sender = msg.sender;
        uint256 vestingAmount = calculateVestingAmount(round, sender);
        bool success = token.transfer(sender, vestingAmount);

        require(success, 'invalid transfer');
        roundData[round].accounts[sender].unlockedBalance += vestingAmount;

        emit Claim(round, sender, vestingAmount);
    }

    function calculateVestingAmount(RoundType _round, address _account) internal view returns (uint256) {
        RoundData storage round = roundData[_round];
        AccountData memory account = round.accounts[_account];

        uint256 initialUnlock = account.balance * round.initialUnlock / MAX_BPS;
        uint256 timePassed = (block.timestamp - round.cliff - _tokenSaleEndTimestamp) > round.vestingPeriod ? round.vestingPeriod : (block.timestamp - round.cliff - _tokenSaleEndTimestamp);
        uint256 pendingTokens = (account.balance - initialUnlock) * timePassed / round.vestingPeriod;
        uint256 availableTokens = initialUnlock + pendingTokens - account.unlockedBalance;

        return availableTokens;
    }

    function getAccountLockedBalance(RoundType round, address account) external view returns(uint256) {
        return roundData[round].accounts[account].balance;
    }

    function getRoundParticipants(RoundType round) external view returns(address[] memory) {
        return roundData[round].accountList;
    }

}