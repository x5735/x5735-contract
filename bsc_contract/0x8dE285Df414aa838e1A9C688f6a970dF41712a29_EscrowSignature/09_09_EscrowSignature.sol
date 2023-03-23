// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

enum TradeStatus {
    Null,
    Active,
    Accepted,
    Canceled
}

struct Trade {
    address buyer;
    address seller;
    address token;
    uint256 amount;
    TradeStatus status;
    uint256 cooldown;
}

/// @title Escrow Signature Contract
/// @dev escrow contract for steam trades
contract EscrowSignature is Ownable {
    using SafeERC20 for IERC20;
    using Strings for uint64;

    /// @dev platform fee rate for trades
    uint16 public tradeFee;

    /// @dev trade fee basis
    uint16 constant public TRADE_FEE_BASIS = 10000;

    /// @dev fee receiver address
    address public feeReceiver;

    /// @dev signer address
    address public signer;

    /// @dev trade cooldown for buyer
    uint256 public cooldown = 10 minutes;

    /// @dev message prefix for signatures
    bytes constant MESSAGE_PREFIX = "\x19Ethereum Signed Message:\n32";

    /// @dev tradeId => Trade
    mapping(uint64 => Trade) public trades;

    /// @dev whitelisted stablecoins
    mapping(address => bool) public tokens;

    event Deposit(address indexed buyer, address indexed seller, uint256 indexed amount, address token, uint64 tradeId);
    event Withdraw(address indexed buyer, uint256 indexed amount, address token, uint64 tradeId);
    event Accept(address indexed buyer, address indexed seller, uint256 indexed amount, address token, uint64 tradeId);

    constructor(uint16 _tradeFee, address _feeReceiver, address _signer) {
        tradeFee = _tradeFee;
        feeReceiver = _feeReceiver;
        signer = _signer;
    }

    /// @notice deposit funds into escrow
    /// @param _seller seller address
    /// @param _tradeId steam trade id
    function deposit(address _seller, uint64 _tradeId, address _token, uint256 _amount) public {
        require(_amount > 0, "Deposit must be greater than 0");
        require(_seller != address(0), "Invalid seller address");
        require(trades[_tradeId].status == TradeStatus.Null, "Trade already exists");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(tokens[_token], "Token is not whitelisted");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        trades[_tradeId].amount = _amount;
        trades[_tradeId].token = _token;
        trades[_tradeId].cooldown = block.timestamp + cooldown;
        trades[_tradeId].status = TradeStatus.Active;
        trades[_tradeId].buyer = msg.sender;
        trades[_tradeId].seller = _seller;

        emit Deposit(msg.sender, _seller, _amount, _token, _tradeId);
    }

    /// @notice accepts given trade and sends funds to seller
    /// @param _tradeId steam trade id
    function release(
        uint64 _tradeId, 
        uint8 _status,
        uint256 _timestamp,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s
    ) public {
        Trade memory trade = trades[_tradeId];
        require(trade.status == TradeStatus.Active, "Trade is not active");

        require(_timestamp >= block.timestamp, "Invalid timestamp");
        require(msg.sender == trade.buyer || msg.sender == trade.seller, "Invalid sender");
        require(msg.sender == trade.seller || block.timestamp >= trade.cooldown, "Trade is still on cooldown");

        bytes32 hashedMessage = keccak256(abi.encodePacked(_tradeId, _status, _timestamp));
        bytes32 prefixedHash = keccak256(abi.encodePacked(MESSAGE_PREFIX, hashedMessage));
        require(ecrecover(prefixedHash, _v, _r, _s) == signer, "Invalid signature");

        if(_status == 6 || _status == 7) {
            IERC20(trade.token).safeTransfer(trade.buyer, trade.amount);
            trades[_tradeId].status = TradeStatus.Canceled;

            emit Withdraw(trade.buyer, trade.amount, trade.token, _tradeId);
        } else if(_status == 3) {
            uint256 fee = (trade.amount * tradeFee) / TRADE_FEE_BASIS;
            uint256 amount = trade.amount - fee;

            IERC20(trade.token).safeTransfer(trade.seller, amount);
            IERC20(trade.token).safeTransfer(feeReceiver, fee);
            trades[_tradeId].status = TradeStatus.Accepted;

            emit Accept(trade.buyer, trade.seller, trade.amount, trade.token, _tradeId);
        } else {
            revert("Invalid trade status");
        }
    }

    /// @notice sets trade fee
    function setTradeFee(uint16 _tradeFee) public onlyOwner {
        require(_tradeFee < TRADE_FEE_BASIS, "Trade fee must be less than 100%");
        tradeFee = _tradeFee;
    }

    /// @notice sets fee receiver address
    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        require(_feeReceiver != address(0), "Invalid fee receiver address");
        feeReceiver = _feeReceiver;
    }

    /// @notice sets trade expiration time
    function setCooldown(uint256 _cooldown) public onlyOwner {
        cooldown = _cooldown;
    }

    /// @notice sets signer address
    function setSignerAddress(address _signer) public onlyOwner {
        require(_signer != address(0), "Invalid signer address");
        signer = _signer;
    }

    /// @notice sets token status
    function setToken(address token, bool _status) public onlyOwner {
        tokens[token] = _status;
    }
}