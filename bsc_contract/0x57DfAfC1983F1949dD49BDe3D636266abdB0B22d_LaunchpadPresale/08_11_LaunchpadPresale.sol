// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Extension/ILaunchpadVault.sol";
import "./Extension/FeeCollector.sol";
import "../Token/IERC20Delegated.sol";

contract LaunchpadPresale is Ownable, FeeCollector {
    using SafeERC20 for IERC20;

    uint256 public minAllocate;
    uint256 public maxAllocate;
    uint256 public targetAmount;
    uint256 public remainAmount;
    uint256 public raisedAmount;
    uint256 public secureAmount;
    uint256 public freezeAmount;
    uint256 public sumAllocates;
    uint256 public startBlock;
    uint256 public pivotBlock;
    uint256 public closeBlock;
    uint256 public realStartBlock;
    uint256 public realPivotBlock;
    uint256 public realCloseBlock;
    uint256 public iniDeposit;
    uint256 public sumDeposit;

    mapping(address => uint256) internal deposits;
    mapping(address => uint256) internal withdraws;
    mapping(address => uint256) internal allocates;
    mapping(address => uint256) internal releases;

    IERC20Delegated public depoToken;
    IERC20 public saleToken;
    ILaunchpadVault public vault;

    uint256 public stage;
    uint256 public setupFlag;
    uint256 public fine;
    uint256 public fineDivisor;
    uint256 public multiply;

    bool private startInProgress;
    bool private closeInProgress;
    bool private salePremature;
    bool private saleSucceeded;
    uint256 private presaleAmount;
    uint256 private pubsaleAmount;

    event ConstraintChanged(uint256 minAllocate, uint256 maxAllocate, uint256 targetAmount, uint256 remainAmount);
    event StartBlockChanged(uint256 block);
    event PivotBlockChanged(uint256 block);
    event CloseBlockChanged(uint256 block);
    event TokenAddressChanged(address indexed depoToken, address indexed saleToken);
    event VaultAddressChanged(address indexed addr);
    event SaleStarted(uint256 block);
    event SaleStopped(uint256 block);
    event StagePushed(uint256 block, uint256 stage);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Allocated(address indexed user, uint256 amount);
    event Delivered(address indexed user, uint256 amount);
    event Released(address indexed user, uint256 amount);
    event WithdrawFineChanged(uint256 fine, uint256 divisor);

    function startSale() external onlyOwner {
        require(stage == 0, 'Presale: already started');
        require(!startInProgress && stage == 0, 'Presale: not ready to be started');
        require(setupFlag == 63, 'Presale: constraints have not been set');
        startInProgress = true;
        raisedAmount = 0; // fix for non-allocation start
        updateState();
    }

    function closeSale() external onlyOwner {
        require(stage <= 3, 'Presale: already stopped');
        require(!closeInProgress && stage == 3, 'Presale: not ready to be stopped');
        require(startInProgress, 'Presale: start of sale needs to be triggered before close');
        closeInProgress = true;
        raisedAmount = saleToken.balanceOf(address(this)); // fix for non-allocation close
        updateState();
    }

    function setConstraint(uint256 minAllocate_, uint256 maxAllocate_, uint256 targetAmount_, uint256 remainAmount_) public onlyOwner {
        require(maxAllocate_ >= minAllocate_, 'Presale: max allocation needs to be higher or equal to min allocation');
        require(targetAmount_ >= maxAllocate_, 'Presale: presale target needs to be higher or equal to max allocation');
        require(targetAmount_ >= remainAmount_, 'Presale: presale target needs to be higher or equal to remain amount');
        require(targetAmount_ > 0, 'Presale: presale target needs to be higher than zero');

        require(minAllocate == 0 && maxAllocate == 0 && targetAmount == 0 && remainAmount == 0,
            'Presale: constraints already set');

        minAllocate = minAllocate_;
        maxAllocate = maxAllocate_;
        targetAmount = targetAmount_;
        remainAmount = remainAmount_;

        setupFlag = setupFlag | 1;
        emit ConstraintChanged(minAllocate, maxAllocate, targetAmount, remainAmount);
    }

    function setTokenAddress(IERC20Delegated _depoToken, IERC20 _saleToken) public onlyOwner {
        require(address(_depoToken) != address(0), 'Presale: token address needs to be different than zero!');
        require(address(_saleToken) != address(0), 'Presale: token address needs to be different than zero!');
        require(address(depoToken) == address(0), 'Presale: token already set!');
        require(address(saleToken) == address(0), 'Presale: token already set!');

        depoToken = _depoToken;
        saleToken = _saleToken;

        setupFlag = setupFlag | 2;
        emit TokenAddressChanged(address(depoToken), address(saleToken));
    }

    function setVaultAddress(ILaunchpadVault _vault) public onlyOwner {
        require(address(_vault) != address(0), 'Presale: vault address needs to be different than zero!');
        require(address(vault) == address(0), 'Presale: vault already set!');
        vault = _vault;

        setupFlag = setupFlag | 4;
        emit VaultAddressChanged(address(vault));
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        require(startBlock == 0, 'Presale: start block already set');
        require(_startBlock > 0, 'Presale: start block needs to be higher than zero!');
        startBlock = _startBlock;

        setupFlag = setupFlag | 8;
        emit StartBlockChanged(startBlock);
    }

    function setPivotBlock(uint256 _pivotBlock) public onlyOwner {
        require(startBlock != 0, 'Presale: start block needs to be set first');
        require(pivotBlock == 0, 'Presale: pivot block already set');
        require(_pivotBlock > startBlock, 'Presale: pivot block needs to be higher than start one!');
        pivotBlock = _pivotBlock;

        setupFlag = setupFlag | 16;
        emit PivotBlockChanged(pivotBlock);
    }

    function setCloseBlock(uint256 _closeBlock) public onlyOwner {
        require(pivotBlock != 0, 'Presale: pivot block needs to be set first');
        require(closeBlock == 0, 'Presale: close block already set');
        require(_closeBlock > pivotBlock, 'Presale: close block needs to be higher than pivot one!');
        closeBlock = _closeBlock;

        setupFlag = setupFlag | 32;
        emit CloseBlockChanged(closeBlock);
    }

    function setWithdrawFine(uint256 _fine, uint256 _divisor) public onlyOwner {
        require(_divisor > 0, 'Presale: fine divisor needs to be higher than zero!');
        fine = _fine;
        fineDivisor = _divisor;
        emit WithdrawFineChanged(_fine, _divisor);
    }

    function isDepositAccepted() public view returns (bool) {
        return stage == 1;
    }

    function isAllocateAccepted() public view returns (bool) {
        return stage == 1 || stage == 2 || stage == 3;
    }

    function isWithdrawAccepted() public view returns (bool) {
        return stage == 4;
    }

    function isReleaseAccepted() public view returns (bool) {
        return stage == 4;
    }

    function isInvestorAllowed(address addr) public view returns (bool) {
        return allowedAllocation(addr) > 0;
    }

    function isPreCloseAllowed() public view returns (bool) {
        return stage == 2;
    }

    function isCountingAllowed() public view returns (bool) {
        return stage == 2 || stage == 3 || stage == 4;
    }

    function isEveryoneAllowed() public view returns (bool) {
        return stage == 3 || (stage == 2 && sumDeposit == 0);
    }

    function depositToAllocation(uint256 amount, uint256 target) public view returns (uint256) {
        return (sumDeposit == 0) ? 0 : amount * target / sumDeposit;
    }

    function currentDeposit(address addr) public view returns (uint256) {
        return deposits[addr];
    }

    function allowedAllocation(address addr) public view returns (uint256) {
        return depositToAllocation(currentDeposit(addr), targetAmount);
    }

    function securedAllocation(address addr) public view returns (uint256) {
        return allowedAllocation(addr) - missingAllocation(addr);
    }

    function currentAllocation(address addr) public view returns (uint256) {
        return allocates[addr];
    }

    function missingAllocation(address addr) public view returns (uint256) {
        uint256 allowed = allowedAllocation(addr);
        uint256 current = currentAllocation(addr);
        return (allowed >= current) ? allowed - current : 0;
    }

    function deposit(uint256 amount) external payable collectFee('deposit') {
        updateState();
        // zero amount is required to be allowed!
        require(isDepositAccepted(), 'Presale: deposits are not accepted at this time!');

        // check expiration of provided tokens
        uint256 expiry = vault.currentUserInfoAt(msg.sender, 4); // expiration is at index=4
        require(expiry >= block.timestamp, 'Presale: your tokens have expired, please re-issue them');

        deposits[msg.sender] = deposits[msg.sender] + amount;
        sumDeposit = sumDeposit + amount;

        // if user allocated on deposit phase already, increase his deposit, ignore otherwise
        if (isDepositAccepted() && currentAllocation(msg.sender) != 0) {
            iniDeposit = iniDeposit + amount;
        }

        IERC20(depoToken).safeTransferFrom(address(msg.sender), address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function allocate(uint256 amount) external payable collectFee('allocate') {
        updateState();
        // zero amount is required to be allowed!
        require(isAllocateAccepted(), 'Presale: allocations are not accepted at this time!');

        bool isInvestor = isInvestorAllowed(msg.sender);
        bool isEveryone = isEveryoneAllowed();
        require(isInvestor || isEveryone, 'Presale: you are not allowed to participate at this time!');
        bool targetReached = raisedAmount + remainAmount >= targetAmount;
        uint256 balance = saleToken.balanceOf(address(this));

        // if user allocated on deposit phase for the first time, count and add his deposit tokens
        if (isDepositAccepted() && currentAllocation(msg.sender) == 0 && amount > 0) {
            iniDeposit = iniDeposit + currentDeposit(msg.sender);
        }
        // if counter phase is active and raisedAmount from previous phase is yet to be determined - count it
        if (isCountingAllowed() && presaleAmount == 0 && !targetReached) {
            balance = balance < targetAmount ? balance : targetAmount;
            balance = depositToAllocation(iniDeposit, balance);
            raisedAmount = raisedAmount + balance;
            if (raisedAmount > targetAmount) raisedAmount = targetAmount;
            secureAmount = secureAmount + balance;
            if (secureAmount > targetAmount) secureAmount = targetAmount;
            presaleAmount = raisedAmount;
        }
        if (isEveryoneAllowed() && pubsaleAmount == 0 && !targetReached) {
            raisedAmount = balance;
            if (raisedAmount > targetAmount) raisedAmount = targetAmount;
            pubsaleAmount = raisedAmount;
        }

        // compute secure allocation allowed
        uint256 newAmount = computeAllocation(msg.sender, amount);
        require(newAmount > 0 || isInvestor, 'Presale: unable to allocate that amount at this time!');

        allocates[msg.sender] = allocates[msg.sender] + amount;
        sumAllocates = saleToken.balanceOf(address(this)) + amount;

        // if counter phase is active, increase raisedAmount by allowed amount
        if (!isDepositAccepted() && isAllocateAccepted()) {
            if (isInvestor) secureAmount = secureAmount + newAmount; // secured amount is a feature available only for investors
            raisedAmount = raisedAmount + newAmount;
        }

        targetReached = raisedAmount + remainAmount >= targetAmount;
        // if everyone is already accepted and real balance is higher than target, accept overbalance and succeed
        if (!targetReached && isEveryone) {
            uint256 actualAmount = sumAllocates;
            if (actualAmount + remainAmount >= targetAmount) {
                raisedAmount = actualAmount <= targetAmount ? actualAmount : targetAmount;
                targetReached = true;
            }
        }
        // if preclose phase is active and only remainAmount is missing treat sale as prematurely succeeded
        if ( targetReached && isPreCloseAllowed()) {
            salePremature = true;
        }
        // if counting phase is active and only remainAmount is missing treat sale as succeeded
        if ( targetReached && isCountingAllowed()) {
            saleSucceeded = true;
        }
        if ( targetReached) {
            updateState(); // stop presale and update state if sale succeeded
        }

        saleToken.safeTransferFrom(address(msg.sender), address(this), amount);
        emit Allocated(msg.sender, amount);
    }

    function withdraw() external payable collectFee('withdraw') {
        updateState();
        require(isWithdrawAccepted(), 'Presale: withdraws are not accepted at this time!');

        uint256 amount = currentDeposit(msg.sender) - withdraws[msg.sender];
        require(amount > 0, 'Presale: unable to withdraw that amount at this time!');

        withdraws[msg.sender] = withdraws[msg.sender] + amount;

        uint256 burned = 0;
        uint256 maxAlloc = allowedAllocation(msg.sender);
        uint256 curAlloc = securedAllocation(msg.sender);

        if (!salePremature && maxAlloc > curAlloc && fine > 0 && fineDivisor > 0) {
            burned = amount * fine / fineDivisor;
            amount = amount - burned;
        }
        if (amount != 0) {
            IERC20(depoToken).safeTransfer(address(msg.sender), amount);
            emit Withdrawn(msg.sender, amount);
        }
        if (burned != 0) {
            depoToken.burn(burned);
            uint256 newBurned = vault.decreasePeggedAmount(address(msg.sender), burned);
            require(newBurned == burned, 'Presale: unable to burn that number of funds');
            emit Withdrawn(address(0), burned);
        }
    }

    function release() external payable collectFee('release') {
        updateState();
        require(isReleaseAccepted(), 'Presale: unable to release yet!');

        uint256 securedAlloc = securedAllocation(msg.sender);
        uint256 currentAlloc = currentAllocation(msg.sender);

        uint256 unlockAmount = ((currentAlloc - securedAlloc) * multiply / 1000) - releases[msg.sender];
        require(releases[msg.sender] == 0, 'Presale: funds were already released!');
        require(unlockAmount > 0, 'Presale: no overbalance found');

        uint256 actualAmount = saleToken.balanceOf(address(this));
        if (unlockAmount > actualAmount) {
            unlockAmount = actualAmount;
        }

        uint256 lockedAmount = raisedAmount - freezeAmount;
        if (unlockAmount > actualAmount - lockedAmount) {
            unlockAmount = actualAmount - lockedAmount;
        }
        require(unlockAmount > 0, 'Presale: no funds available for release!');
        releases[msg.sender] = releases[msg.sender] + unlockAmount;

        saleToken.safeTransfer(address(msg.sender), unlockAmount);
        emit Released(msg.sender, unlockAmount);
    }

    function deliver(address addr, uint256 amount) external payable collectFee('deliver') onlyOwner {
        updateState();
        require(isReleaseAccepted(), 'Presale: unable to release yet!');

        uint256 unlockAmount = amount;
        uint256 queuedAmount = raisedAmount - freezeAmount;
        if (unlockAmount > queuedAmount) {
            unlockAmount = queuedAmount;
        }
        require(unlockAmount > 0, 'Presale: funds were already delivered!');

        uint256 actualAmount = saleToken.balanceOf(address(this));
        if (unlockAmount > actualAmount) {
            unlockAmount = actualAmount;
        }
        require(unlockAmount > 0, 'Presale: funds were already delivered!');
        freezeAmount = freezeAmount + unlockAmount;

        saleToken.safeTransfer(addr, unlockAmount);
        emit Delivered(msg.sender, unlockAmount);
    }

    function computeAllocation(address addr, uint256 amount) private view returns (uint256) {
        uint256 newAmount = amount;
        bool isInvestor = isInvestorAllowed(addr);
        bool isEveryone = isEveryoneAllowed();
        if (raisedAmount + newAmount > targetAmount) {
            newAmount = targetAmount - raisedAmount;
        }
        if (isInvestor) {
            uint256 misAmount = missingAllocation(addr);
            if (newAmount > misAmount) {
                newAmount = misAmount;
            }
            return newAmount;
        }
        if (isEveryone) {
            uint256 curAmount = currentAllocation(addr);
            if (minAllocate != 0 && curAmount + newAmount < minAllocate) {
                newAmount = 0;
            }
            if (maxAllocate != 0 && curAmount > maxAllocate) {
                newAmount = 0;
            }
            if (maxAllocate != 0 && curAmount + newAmount > maxAllocate) {
                newAmount = maxAllocate - curAmount;
            }
            return newAmount;
        }
        return 0;
    }

    function updateState() private {
        if (stage == 0) {
            if (!startInProgress) {
                return;
            }
            if (realStartBlock == 0 && startBlock > 0 && block.number >= startBlock) {
                updateStage(1);
                return updateState();
            }
        }
        if (stage == 1) {
            if (realStartBlock == 0) {
                realStartBlock = block.number;
            }
            if (realPivotBlock == 0 && pivotBlock > 0 && block.number >= pivotBlock) {
                updateStage(2);
                return updateState();
            }
        }
        if (stage == 2) {
            if (realPivotBlock == 0) {
                realPivotBlock = block.number;
            }
            if (realCloseBlock == 0 && raisedAmount + remainAmount >= targetAmount) {
                updateStage(3);
                return updateState();
            }
            if (realCloseBlock == 0 && closeBlock > 0 && block.number >= closeBlock) {
                updateStage(3);
                return updateState();
            }
        }
        if (stage == 3) {
            if (realCloseBlock == 0 && raisedAmount + remainAmount >= targetAmount) {
                updateStage(4);
                return updateState();
            }
            if (realCloseBlock == 0 && closeInProgress) {
                updateStage(4);
                return updateState();
            }
        }
        if (stage == 4) {
            if (realCloseBlock == 0) {
                realCloseBlock = block.number;
                exitPresale(); // close for good
            }
        }
    }

    function updateStage(uint256 _stage) private {
        stage = _stage;
        emit StagePushed(block.number, stage);
    }

    function exitPresale() private {
        uint256 one = 1000;
        uint256 currentBalance = sumAllocates;
        multiply = one;
        if (currentBalance > secureAmount) {
            multiply = one * (raisedAmount - secureAmount) / (currentBalance - secureAmount);
        }
        if (multiply > one) {
            multiply = one;
        }
        multiply = one - multiply;
    }
}