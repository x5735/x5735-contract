// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title GameWallet
 * @dev A contract for managing participants' token balances and distributing prizes.
 */
contract GameWallet is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Address of prize token
    IERC20Upgradeable public prizeToken;

    // Mapping for users balance
    mapping(address => uint256) public pBalance;

    // Mapping for withdraw lock
    mapping(address => uint256) public lockUntil;

    uint256[50] private __gap;

    // prize fee in basis points (bps), representing a fraction of 10,000
    // For example, a prizeFee of 200 means 200 basis points or 2% of the total prize amount
    uint256 public prizeFee;

    // treasury address
    address public treasury;

    // prize fond wallet address
    address public prizeFondWallet;

    // Lock duration in seconds 10 minutes default (60s * 10m)
    uint256 public lockDuration = 600;

    // Participant struct
    struct Participant {
        address account;
        uint256 winningPerMille;
        bool isWinner;
    }

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Deducted(address indexed account, uint256 amount);
    event WonPrize(address indexed account, uint256 amount);
    event PrizeFeeSent(address indexed account, uint256 amount);

    /**
    @param tokenAddress_ the token address for prize
     */
    function initialize(address tokenAddress_) external initializer {
        require(tokenAddress_ != address(0), "Invalid token address");
        __Ownable_init();

        prizeToken = IERC20Upgradeable(tokenAddress_);
    }

    /**
    @dev Allows deposit or withdraw of tokens.
    @param _deposit If true, deposit tokens; otherwise, withdraw tokens.
    @param _amount Amount of tokens to deposit or withdraw.
     */
    function manageBalance(bool _deposit, uint256 _amount) external {
        if (_deposit) {
            prizeToken.safeTransferFrom(msg.sender, address(this), _amount);
            pBalance[msg.sender] += _amount;
            emit Deposited(msg.sender, _amount);
        } else {
            require(pBalance[msg.sender] >= _amount, "Not enough token deposited");
            require(block.timestamp >= lockUntil[msg.sender], "Account locked for withdraw");

            pBalance[msg.sender] -= _amount;
            prizeToken.safeTransfer(msg.sender, _amount);

            emit Withdrawn(msg.sender, _amount);
        }
    }

    ///////////////////////
    /// Owner Functions ///
    ///////////////////////

    /**
    @dev Distributes prizes to winners based on their winning per mille.
    @param _participants Array of participants.
    @param _prizePoolAmount Prize pool amount.
    @param _distributeFromPrizeFondWallet If true, distribute prize from the prizeFondWallet; otherwise, distribute from entry fees.
    */
    function winPrize(
        Participant[] memory _participants,
        uint256 _prizePoolAmount,
        bool _distributeFromPrizeFondWallet
    ) external onlyOwner {
        require(_participants.length != 0, "Invalid participants array");

        uint256 sum;
        uint256 i;

        if (!_distributeFromPrizeFondWallet) {
            uint256 participantEntryFee = _prizePoolAmount / _participants.length;

            // Process participants and collect entry fees
            for (i; i < _participants.length; i++) {
                address participantAccount = _participants[i].account;
                bool isWinner = _participants[i].isWinner;

                if (!isWinner) {
                    require(
                        pBalance[participantAccount] >= participantEntryFee,
                        "Not enough balance deposited"
                    );

                    pBalance[participantAccount] -= participantEntryFee;
                    sum += participantEntryFee;
                    emit Deducted(participantAccount, participantEntryFee);
                }
            }
        } else {
            require(
                pBalance[prizeFondWallet] >= _prizePoolAmount,
                "Not enough balance in prize fond wallet"
            );
            sum = _prizePoolAmount;
            pBalance[prizeFondWallet] -= _prizePoolAmount;
        }

        // Check if total winning per mille is 1000
        uint256 totalWinningPerMille = 0;
        for (i = 0; i < _participants.length; i++) {
            if (_participants[i].isWinner) {
                totalWinningPerMille += _participants[i].winningPerMille;
            }
        }
        require(totalWinningPerMille == 1000, "Total winning per mille must be 1000");

        // sent royalty to tresury
        if ((sum * prizeFee) / 1e4 != 0 && treasury != address(0)) {
            pBalance[treasury] += (sum * prizeFee) / 1e4;
            emit PrizeFeeSent(treasury, (sum * prizeFee) / 1e4);
            sum -= (sum * prizeFee) / 1e4;
        }

        // Distribute prizes based on winning per mille
        for (i = 0; i < _participants.length; i++) {
            if (_participants[i].isWinner) {
                address winnerAccount = _participants[i].account;
                uint256 winnerPerMille = _participants[i].winningPerMille;

                uint256 prizeAmount = (sum * winnerPerMille) / 1000;
                pBalance[winnerAccount] += prizeAmount;
                emit WonPrize(winnerAccount, prizeAmount);
            }
        }
    }

    /**
    @dev Locks the accounts for a specified duration.
    @param _accounts Array of accounts to lock.
     */
    function lockAccounts(address[] memory _accounts) external onlyOwner {
        require(_accounts.length != 0, "Invalid array length");

        for (uint256 i; i < _accounts.length; i++) {
            lockUntil[_accounts[i]] = block.timestamp + lockDuration;
        }
    }

    /**
    @dev Sets the treasury address.
    @param _treasury Treasury address.
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    /**
    @dev Sets the prize fond wallet address.
    @param _prizeFondWallet Prize fond wallet address.
     */
    function setPrizeFondWallet(address _prizeFondWallet) external onlyOwner {
        require(_prizeFondWallet != address(0), "Invalid prize fond wallet address");
        prizeFondWallet = _prizeFondWallet;
    }

    /**
    @dev Sets the prize fee.
    @param _prizeFee Prize fee value (must be less than or equal to 2000 -> 20%).
     */
    function setPrizeFee(uint256 _prizeFee) external onlyOwner {
        require(_prizeFee <= 2e3, "Invalid prize fee value");
        prizeFee = _prizeFee;
    }

    /**
    @dev Sets the lock duration.
    @param _lockDuration Lock duration in seconds.
     */
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }
}