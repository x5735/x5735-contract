//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

struct Loan {
    address borrower;
    address lender;

    uint256 collateralAmount;
    uint256 borrowedAmount;
    uint256 borrowingTime;

    bool closed;
}

struct Lend {
    address lender;

    uint256 initialAmount;
    uint256 leftAmount;

    uint256 prev;
    uint256 next;
    bool dropped;
}

contract MinterLoans is IMinterLoans, Ownable {
    using SafeERC20 for IERC20;

    IERC20 coin0;
    IERC20 coin1;
    IPancakeRouter pancake;

    IWBNB wbnb = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    Loan[] loans;

    uint256 public lendsHead;
    uint256 public lendsTail;
    Lend[] public lends;

    uint256 public price;
    uint256 public priceDenom = 1e8;

    uint256 constant public minimalLoanableAmount = 0.001 ether;
    uint256 constant public maximalLoanableAmount = 100 ether;

    uint256 constant public minCollateralRate = 75;
    uint256 constant public baseCollateralRate = 200;
    uint256 constant public rateDenom = 100;
    uint256 constant public interestPerMonth = 1;
    uint256 constant public interestDenom = 100;
    uint256 constant public maxBorrowingPeriod = 365 days;

    address public fundAddress = 0x18467bbB64a8eDF890201D526c35957d82be3d95;
    uint256 public fundFee = 10;
    uint256 public fundFeeDenom = 100;

    constructor(address _coin0Address, address _coin1Address, uint256 _price, address _pancakeAddress) {
        coin0 = IERC20(_coin0Address);
        coin1 = IERC20(_coin1Address);
        price = _price;
        pancake = IPancakeRouter(_pancakeAddress);
    }

    receive() external payable {
        assert(msg.sender == address(wbnb));
    }

    function buyWithLeverage(uint256 _coin1Amount, uint256 _amountOutMin) override external {
        coin1.safeTransferFrom(msg.sender, address(this), _coin1Amount);
        _buyWithLeverage(_coin1Amount, _amountOutMin);
    }

    function buyWithLeverageBNB(uint256 _amountOutMin) payable override external {
        wbnb.deposit{value: msg.value}();
        _buyWithLeverage(msg.value, _amountOutMin);
    }

    function _buyWithLeverage(uint256 _coin1Amount, uint256 _amountOutMin) internal {
        uint256 maxLoanAmount = _coin1Amount;

        require(maxLoanAmount >= minimalLoanableAmount, "Loanable amount is too small");
        require(lends.length > 0 && !lends[lendsHead].dropped && lends[lendsHead].leftAmount > 0, "No available lends");

        uint256 currentLendId = lendsHead;
        uint256 loanedAmount = 0;
        uint256 totalCollateral = 0;

        for(;;) {
            Lend memory currentLend = lends[currentLendId];

            require(!currentLend.dropped);
            require(currentLend.leftAmount > 0);

            uint256 currentLoanAmount = maxLoanAmount - loanedAmount;
            if (currentLend.leftAmount < currentLoanAmount) {
                currentLoanAmount = currentLend.leftAmount;
            }

            address[] memory path = new address[](2);
            path[0] = address(coin1);
            path[1] = address(coin0);

            coin1.approve(address(pancake), currentLoanAmount * 2);

            uint[] memory amounts = pancake.swapExactTokensForTokens(
                currentLoanAmount * 2, 0, path, address(this), block.timestamp + 1
            );

            uint256 currentCollateralAmount = amounts[path.length - 1];

            loans.push(Loan(msg.sender, currentLend.lender, currentCollateralAmount, currentLoanAmount, block.timestamp, false));
            lends[currentLendId].leftAmount -= currentLoanAmount;
            emit NewLoan(currentLend.lender, msg.sender, loans.length - 1, currentLoanAmount, currentCollateralAmount);

            if (lends[currentLendId].leftAmount == 0) {
                removeLend(currentLendId);
            }

            loanedAmount += currentLoanAmount;
            totalCollateral += currentCollateralAmount;

            if (maxLoanAmount == loanedAmount) {
                require(_amountOutMin <= totalCollateral, "INSUFFICIENT_OUTPUT_AMOUNT");
                break;
            }

            if (currentLendId == lendsTail) {
                if (address(coin1) == address(wbnb)) {
                    wbnb.withdraw(_coin1Amount - loanedAmount);
                    payable(msg.sender).transfer(_coin1Amount - loanedAmount);
                } else {
                    coin1.transfer(msg.sender, _coin1Amount - loanedAmount);
                }

                require(_amountOutMin <= totalCollateral, "INSUFFICIENT_OUTPUT_AMOUNT");
                break;
            }

            currentLendId = currentLend.next;
        }
    }

    function borrow(uint256 _collateralAmount) override external {
        uint256 maxLoanAmount = calculateLoanAmount(_collateralAmount);

        require(maxLoanAmount >= minimalLoanableAmount, "Loanable amount is too small");
        require(lends.length > 0 && !lends[lendsHead].dropped && lends[lendsHead].leftAmount > 0, "No available lends");

        coin0.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        uint256 currentLendId = lendsHead;
        uint256 loanedAmount = 0;
        uint256 collateralLeft = _collateralAmount;

        for(;;) {
            Lend memory currentLend = lends[currentLendId];

            require(!currentLend.dropped);
            require(currentLend.leftAmount > 0);

            uint256 currentLoanAmount = maxLoanAmount - loanedAmount;
            uint256 currentCollateralAmount = collateralLeft;
            if (currentLend.leftAmount < currentLoanAmount) {
                currentCollateralAmount = calculateCollateralAmount(currentLend.leftAmount);
                currentLoanAmount = currentLend.leftAmount;
            }

            loans.push(Loan(msg.sender, currentLend.lender, currentCollateralAmount, currentLoanAmount, block.timestamp, false));
            lends[currentLendId].leftAmount -= currentLoanAmount;
            emit NewLoan(currentLend.lender, msg.sender, loans.length - 1, currentLoanAmount, currentCollateralAmount);

            if (lends[currentLendId].leftAmount == 0) {
                removeLend(currentLendId);
            }

            loanedAmount += currentLoanAmount;
            collateralLeft -= currentCollateralAmount;

            if (maxLoanAmount == loanedAmount) {
                break;
            }

            if (currentLendId == lendsTail) {
                coin0.safeTransfer(msg.sender, collateralLeft);
                break;
            }

            currentLendId = currentLend.next;
        }

        if (address(coin1) == address(wbnb)) {
            wbnb.withdraw(loanedAmount);
            payable(msg.sender).transfer(loanedAmount);
        } else {
            coin1.transfer(msg.sender, loanedAmount);
        }
    }

    function repay(uint256 _loanId) override external {
        Loan memory loan = loans[_loanId];
        require(!loan.closed, "Loan has been already closed");
        require(loan.borrower == msg.sender, "Sender is not a borrower of loan");

        uint256 amountToRepay = calculateRepayAmount(loan);

        coin1.safeTransferFrom(msg.sender, loan.lender, amountToRepay);
        coin0.safeTransfer(msg.sender, loan.collateralAmount);

        loans[_loanId].closed = true;
        emit Repay(_loanId);
    }

    function repayBNB(uint256 _loanId) payable override external {
        Loan memory loan = loans[_loanId];
        require(!loan.closed, "Loan has been already closed");
        require(loan.borrower == msg.sender, "Sender is not a borrower of loan");

        uint256 amountToRepay = calculateRepayAmount(loan);

        payable(loan.lender).transfer(amountToRepay);
        coin0.safeTransfer(msg.sender, loan.collateralAmount);

        loans[_loanId].closed = true;
        emit Repay(_loanId);
    }

    function sellAndRepay(uint256 _loanId, uint256 _amountInMax) override external {
        Loan memory loan = loans[_loanId];
        require(!loan.closed, "Loan has been already closed");
        require(loan.borrower == msg.sender, "Sender is not a borrower of loan");
        require(_amountInMax <= loan.collateralAmount);

        uint256 amountToRepay = calculateRepayAmount(loan);

        address[] memory path = new address[](2);
        path[0] = address(coin0);
        path[1] = address(coin1);

        uint256 amountInMax = loan.collateralAmount;
        if (_amountInMax < amountInMax) {
            amountInMax = _amountInMax;
        }

        coin0.approve(address(pancake), loan.collateralAmount);
        uint[] memory amounts = pancake.swapTokensForExactTokens(
            amountToRepay, amountInMax, path, address(this), block.timestamp + 1
        );
        coin0.approve(address(pancake), 0);

        if (address(coin1) == address(wbnb)) {
            wbnb.withdraw(amountToRepay);
            payable(loan.lender).transfer(amountToRepay);
        } else {
            coin1.transfer(loan.lender, amountToRepay);
        }

        coin0.safeTransfer(msg.sender, loan.collateralAmount - amounts[0]);

        loans[_loanId].closed = true;

        emit Repay(_loanId);
    }

    function lendBNB() payable override external {
        wbnb.deposit{value: msg.value}();
        _lend(msg.value);
    }

    function lend(uint256 _loanableAmount) override external {
        coin1.safeTransferFrom(msg.sender, address(this), _loanableAmount);
        _lend(_loanableAmount);
    }

    function _lend(uint256 _loanableAmount) internal {
        require(_loanableAmount >= minimalLoanableAmount, "Amount is too small");
        require(_loanableAmount <= maximalLoanableAmount, "Amount is too large");

        if (lends.length != 0) {
            lends[lendsTail].next = lends.length;

            if (lends[lendsHead].dropped) {
                lendsHead = lends.length;
            }
        }

        lends.push(Lend(msg.sender, _loanableAmount, _loanableAmount, lendsTail, 0, false));
        lendsTail = lends.length - 1;

        emit NewLend(msg.sender, lends.length - 1, _loanableAmount);
    }

    function withdraw(uint256 _lendId) override external {
        require(lends[_lendId].lender == msg.sender, "Sender is not an owner of lend");

        if (address(coin1) == address(wbnb)) {
            wbnb.withdraw(lends[_lendId].leftAmount);
            payable(lends[_lendId].lender).transfer(lends[_lendId].leftAmount);
        } else {
            coin1.transfer(lends[_lendId].lender, lends[_lendId].leftAmount);
        }

        lends[_lendId].leftAmount = 0;
        removeLend(_lendId);
        emit Withdraw(_lendId);
    }

    function liquidate(uint256 _loanId) override external {
        Loan memory loan = loans[_loanId];
        require(msg.sender == loan.lender, "Sender is not an owner of the debt");
        require(!loan.closed, "Loan has been already closed");

        require(canBeLiquidated(loan), "Loan cannot be liquidated yet");

        uint256 collateral = loan.collateralAmount;

        uint256 toFund = collateral * fundFee / fundFeeDenom;
        uint256 toLender = collateral - toFund;

        coin0.safeTransfer(fundAddress, toFund);
        coin0.safeTransfer(loan.lender, toLender);

        loans[_loanId].closed = true;
        emit Liquidation(_loanId);
    }

    function removeLend(uint256 _id) private {
        lends[_id].dropped = true;

        if (_id == lendsHead) {
            lendsHead = lends[_id].next;
            lends[lends[_id].next].prev = lendsHead;
        } else if (_id == lendsTail) {
            lendsTail = lends[_id].prev;
            lends[lends[_id].prev].next = lendsTail;
        } else {
            lends[lends[_id].next].prev = lends[_id].prev;
            lends[lends[_id].prev].next = lends[_id].next;
        }
    }

    function setFund(address _fundAddress, uint256 _fundFee) public onlyOwner {
        require(_fundFee <= 100);

        fundAddress = _fundAddress;
        fundFee = _fundFee;
    }

    function calculateLoanAmount(uint256 coin0Amount) public view returns(uint256) {
        return coin0Amount * price * rateDenom / baseCollateralRate / priceDenom;
    }

    function calculateCollateralAmount(uint256 coin1Amount) public view returns(uint256) {
        return coin1Amount * priceDenom * baseCollateralRate / price / rateDenom;
    }

    function calculateRepayAmount(Loan memory loan) public view returns(uint256) {
        uint256 monthCount = (block.timestamp - loan.borrowingTime) / 30 days;
        if (monthCount < 1) {
            monthCount = 1;
        }

        return loan.borrowedAmount + (loan.borrowedAmount * monthCount * interestPerMonth / interestDenom);
    }

    function canBeLiquidated(Loan memory loan) public view returns(bool) {
        if ((block.timestamp - loan.borrowingTime) / maxBorrowingPeriod > 0) {
            return true;
        }

        uint256 neededCollateral = calculateCollateralAmount(calculateRepayAmount(loan));

        return loan.collateralAmount * rateDenom / neededCollateral < minCollateralRate;
    }

    function getLoan(uint256 _id) override external view returns(address borrower, address lender, uint256 collateralAmount, uint256 borrowedAmount, uint256 borrowingTime, bool closed, uint256 amountToRepay, bool mayBeLiquidated) {
        Loan memory loan = loans[_id];

        borrower = loan.borrower;
        lender = loan.lender;
        collateralAmount = loan.collateralAmount;
        borrowedAmount = loan.borrowedAmount;
        closed = loan.closed;
        amountToRepay = calculateRepayAmount(loan);
        mayBeLiquidated = canBeLiquidated(loan);
        borrowingTime = loan.borrowingTime;
    }

    function getLend(uint256 _id) override external view returns(address lender, uint256 initialAmount, uint256 leftAmount) {
        return (lends[_id].lender, lends[_id].initialAmount, lends[_id].leftAmount);
    }

    function setPrice(uint256 _price, uint256 _priceDenom) override public onlyOwner {
        price = _price;
        priceDenom = _priceDenom;
    }

    function setFundParams(address _fundAddress, uint256 _fundFee, uint256 _fundFeeDenom) override public onlyOwner {
        fundAddress = _fundAddress;
        fundFee = _fundFee;
        fundFeeDenom = _fundFeeDenom;
    }
}