/**
 *Submitted for verification at BscScan.com on 2023-03-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
}

contract Rolly {
    uint constant MIN_BET = 10;
    uint constant MAX_BET = 100;
    uint constant NUM_POCKETS = 36;
    uint constant HOUSE_EDGE_PERCENT = 2;

    address payable public owner;
    address public tokenAddress;
    uint public tokenDecimals;
    uint public tokenAmount;

    struct Bet {
        address payable player;
        uint value;
        uint pocket;
    }

    mapping(address => uint) public balances;
    Bet[] public bets;

    event BetPlaced(address indexed player, uint indexed value, uint indexed pocket);
    event SpinComplete(uint indexed winningPocket, uint indexed payout);

    constructor() {
        owner = payable(msg.sender);
        tokenAddress = 0x0005Fd45281d89042965aCBAf645ecC86bC5Ec5c;
        tokenDecimals = 18;
        tokenAmount = 1000;
    }

    function placeBet(uint _pocket) public {
        uint betAmount = tokenAmount * 10 ** tokenDecimals;
        require(betAmount >= MIN_BET * 10 ** tokenDecimals && betAmount <= MAX_BET * 10 ** tokenDecimals, "Bet amount is outside allowed range");
        require(_pocket >= 0 && _pocket < NUM_POCKETS, "Pocket number is outside allowed range");

        IERC20 token = IERC20(tokenAddress);
        uint allowance = token.allowance(msg.sender, address(this));
        require(allowance >= betAmount, "Token allowance is not enough");
        require(token.transferFrom(msg.sender, address(this), betAmount), "Token transfer failed");

        Bet memory newBet;
        newBet.player = payable(msg.sender);
        newBet.value = betAmount;
        newBet.pocket = _pocket;
        bets.push(newBet);

        emit BetPlaced(msg.sender, betAmount, _pocket);
    }

    function spin() public {
        require(msg.sender == owner, "Only the owner can spin the wheel");
        require(bets.length > 0, "No bets have been placed");

        uint winningPocket = uint(keccak256(abi.encodePacked(block.timestamp))) % NUM_POCKETS;
        uint totalPayout = 0;

        for (uint i = 0; i < bets.length; i++) {
            Bet storage bet = bets[i];
            if (bet.pocket == winningPocket) {
                uint payout = bet.value * (100 - HOUSE_EDGE_PERCENT) / NUM_POCKETS;
                require(IERC20(tokenAddress).transfer(bet.player, bet.value + payout), "Token transfer failed");
                totalPayout += payout;
            }
        }

        delete bets;
        emit SpinComplete(winningPocket, totalPayout);
    }

    function withdraw() public {
        uint amount = balances[msg.sender];
    require(amount > 0, "You have no balance to withdraw");
        balances[msg.sender] = 0;
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }
}