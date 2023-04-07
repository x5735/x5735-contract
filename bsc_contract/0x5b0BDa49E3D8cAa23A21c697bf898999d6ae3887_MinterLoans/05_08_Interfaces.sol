//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IMinterLoans {
    // events
    event NewLoan(address indexed lender, address indexed borrower, uint256 id, uint256 tokenAmount, uint256 collateralAmount);
    event NewLend(address indexed lender, uint256 id, uint256 tokenAmount);
    event Repay(uint256 indexed loanId);
    event Liquidation(uint256 indexed loanId);
    event Withdraw(uint256 indexed lendId);

    // borrower actions
    function borrow(uint256 _collateralAmount) external;
    function buyWithLeverageBNB(uint256 _amountOutMin) payable external;
    function buyWithLeverage(uint256 _usdtAmount, uint256 _amountOutMin) external;
    function repay(uint256 _loanId) external;
    function repayBNB(uint256 _loanId) payable external;
    function sellAndRepay(uint256 _loanId, uint256 _amountInMax) external;

    // lender actions
    function lend(uint256 _loanableAmount) external;
    function lendBNB() payable external;
    function withdraw(uint256 _lendId) external;
    function liquidate(uint256 _loanId) external;

    // getters
    function getLoan(uint256 id) external view returns(address borrower, address lender, uint256 collateralAmount, uint256 borrowedAmount, uint256 borrowingTime, bool closed, uint256 amountToRepay, bool mayBeLiquidated);
    function getLend(uint256 id) external view returns(address lender, uint256 initialAmount, uint256 leftAmount);

    // owners
    function setPrice(uint256 _price, uint256 _priceDenom) external;
    function setFundParams(address _fundAddress, uint256 _fee, uint256 _feeDenom) external;
}

interface IPancakeRouter {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IWBNB {
    function deposit() external payable;
    function withdraw(uint wad) external;
}