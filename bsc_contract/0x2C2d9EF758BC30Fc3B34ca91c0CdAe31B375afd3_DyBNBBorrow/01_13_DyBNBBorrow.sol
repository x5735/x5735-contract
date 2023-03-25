// contract: DyBorrow.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IVenusBEP20Delegator.sol";
import "./interfaces/IVenusBNBDelegator.sol";
import "./interfaces/IVenusUnitroller.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IPriceOracle.sol";

/**
 ________      ___    ___ ________   ________  _____ ______   ___  ________     
|\   ___ \    |\  \  /  /|\   ___  \|\   __  \|\   _ \  _   \|\  \|\   ____\    
\ \  \_|\ \   \ \  \/  / | \  \\ \  \ \  \|\  \ \  \\\__\ \  \ \  \ \  \___|    
 \ \  \ \\ \   \ \    / / \ \  \\ \  \ \   __  \ \  \\|__| \  \ \  \ \  \       
  \ \  \_\\ \   \/  /  /   \ \  \\ \  \ \  \ \  \ \  \    \ \  \ \  \ \  \____  
   \ \_______\__/  / /      \ \__\\ \__\ \__\ \__\ \__\    \ \__\ \__\ \_______\
    \|_______|\___/ /        \|__| \|__|\|__|\|__|\|__|     \|__|\|__|\|_______|
             \|___|/                                                            

 */

interface IERC20Decimal {
    function decimals() external view returns (uint256);
}

contract DyBNBBorrow is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    // variables, structs and mappings
    uint256 borrowFees;
    uint256 borrowDivisor;
    IVenusUnitroller public rewardController;
    IPriceOracle public oracle;

    uint256 constant BIPS = 1e18;
    uint256 constant ONE_YEAR_IN_SECOND = 365 days;
    address constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address[] vaults;

    mapping(address => address) public delegator;
    mapping(address => mapping(address => uint256)) public borrowingAmount;
    mapping(address => mapping(address => uint256))
        public underlyingBalanceUser;
    mapping(address => mapping(address => uint256)) public borrowTimestamp;
    mapping(address => uint256) public BorrowAPY;
    mapping(address => bool) checkVaults;
    mapping(address => uint256) public assetDecimals;

    // events

    modifier isVault(address vault_) {
        require(
            checkVaults[vault_] == true,
            "[DyBEP20BorrowVenus]::Must be vault"
        );
        _;
    }

    // constructor and functions

    function initialize(
        address rewardController_,
        uint256 borrowFees_,
        uint256 borrowDivisor_,
        address oracle_
    ) public initializer {
        __Ownable_init();

        rewardController = IVenusUnitroller(rewardController_);
        borrowFees = borrowFees_;
        borrowDivisor = borrowDivisor_;
        oracle = IPriceOracle(oracle_);
    }

    function setDelegator(
        address[] memory _underlyings,
        address[] memory _delegators
    ) public onlyOwner {
        for (uint256 i = 0; i <= _underlyings.length - 1; i++) {
            delegator[_underlyings[i]] = _delegators[i];
            vaults.push(_underlyings[i]);
        }
        rewardController.enterMarkets(_delegators);
    }

    function setAPY(uint256 APY_, address token_) public onlyOwner {
        BorrowAPY[token_] = APY_;
    }

    function setDecimal(address token_, uint256 decimal_) public onlyOwner {
        assetDecimals[token_] = decimal_;
    }

    function setCheckVault(bool bool_, address vault_) public onlyOwner {
        checkVaults[vault_] = bool_;
    }

    function setBorrowFee(uint256 _borrowFees) public onlyOwner {
        require(_borrowFees < borrowDivisor, "Fee too high");
        borrowFees = _borrowFees;
    }

    function removeVault(uint256 index_) public onlyOwner {
        require(index_ < vaults.length, "[DyBEP20BorrowVenus]::Invalid index");
        rewardController.exitMarket(vaults[index_]);
        delete vaults[index_];
    }

    function deposit(
        uint256 amount_,
        address depositor_,
        address underlying_
    ) public payable isVault(_msgSender()) {
        require(
            delegator[underlying_] != address(0),
            "[DyBEP20BorrowVenus]::Underlying is not registered."
        );

        IERC20Upgradeable underlying = IERC20Upgradeable(underlying_);
        IVenusBEP20Delegator tokenDelegator = IVenusBEP20Delegator(
            delegator[underlying_]
        );

        // Supplying underlying
        if (underlying_ == WBNB) {
            IVenusBNBDelegator bnbDelegator = IVenusBNBDelegator(
                delegator[underlying_]
            );
            bnbDelegator.mint{value: amount_};
        } else {
            underlying.transferFrom(_msgSender(), address(this), amount_);
            underlying.approve(address(tokenDelegator), amount_);

            require(
                tokenDelegator.mint(amount_) == 0,
                "[DyBEP20BorrowVenus]::Supplying failed"
            );
        }

        underlyingBalanceUser[depositor_][underlying_] += amount_;
    }

    function emergencyWithdraw(
        uint256 amountUnderlying_,
        address withdrawer_,
        address underlying_
    ) public payable onlyOwner {
        IVenusBEP20Delegator tokenDelegator = IVenusBEP20Delegator(
            delegator[underlying_]
        );
        IERC20Upgradeable underlying = IERC20Upgradeable(underlying_);

        uint256 success = tokenDelegator.redeemUnderlying(amountUnderlying_);
        require(success == 0, "[DyBEP20BorrowVenus]::Failed to redeem");

        if (underlying_ == WBNB) {
            (bool transferSuccess, ) = withdrawer_.call{
                value: address(this).balance
            }("");
            require(transferSuccess, "Transfer ETH failed");
        } else {
            uint256 redeemedUnderlyingBalance = underlying.balanceOf(
                address(this)
            );
            underlying.transfer(withdrawer_, redeemedUnderlyingBalance);
        }
    }

    function withdraw(
        uint256 amountUnderlying_,
        address withdrawer_,
        address underlying_
    ) public payable isVault(_msgSender()) {
        require(
            delegator[underlying_] != address(0),
            "[DyBEP20BorrowVenus]::Underlying is not registered."
        );

        (
            uint256 withdrawableAmount,
            uint256 borrowedAmount
        ) = getWithdrawableAmount(withdrawer_, underlying_);

        require(
            amountUnderlying_ <= withdrawableAmount,
            "[DyBEP20BorrowVenus]::Need to pay borrowed"
        );

        IERC20Upgradeable underlying = IERC20Upgradeable(underlying_);
        IVenusBEP20Delegator tokenDelegator = IVenusBEP20Delegator(
            delegator[underlying_]
        );

        // Redeem underlying if satisfy repay condition

        uint256 underlyingBalanceAmount = underlyingBalanceUser[withdrawer_][
            underlying_
        ];

        require(amountUnderlying_ <= underlyingBalanceAmount, "Exceed balance");
        if (borrowedAmount > 0) {
            require(
                amountUnderlying_ < (underlyingBalanceAmount * 2) / 10,
                "Need to repay"
            );
        }
        // uint256 redeemableUnderlying = getRedeemableAmount(underlying_);

        // require(
        //     redeemableUnderlying > 0,
        //     "[DyBEP20BorrowVenus]::Not enough redeemable assets"
        // );

        uint256 finalRedeemableAmount = amountUnderlying_
            .mul(borrowDivisor.sub(borrowFees))
            .div(borrowDivisor);
        // if (
        //     redeemableUnderlying <=
        //     underlyingBalanceAmount.mul(borrowDivisor.sub(borrowFees)).div(
        //         borrowDivisor
        //     )
        // ) {
        //     finalRedeemableAmount = redeemableUnderlying;
        // } else {
        //     finalRedeemableAmount = underlyingBalanceAmount
        //         .mul(borrowDivisor.sub(borrowFees))
        //         .div(borrowDivisor);
        // }

        uint256 success = tokenDelegator.redeemUnderlying(
            finalRedeemableAmount
        );
        require(success == 0, "[DyBEP20BorrowVenus]::Failed to redeem");

        if (underlying_ == WBNB) {
            (bool transferSuccess, ) = withdrawer_.call{
                value: address(this).balance
            }("");
            require(transferSuccess, "Transfer ETH failed");
        } else {
            uint256 redeemedUnderlyingBalance = underlying.balanceOf(
                address(this)
            );
            underlying.transfer(withdrawer_, redeemedUnderlyingBalance);
        }

        underlyingBalanceUser[withdrawer_][underlying_] = underlyingBalanceUser[
            withdrawer_
        ][underlying_].sub(amountUnderlying_);
    }

    function borrow(uint256 _amount, address borrowToken_)
        public
        nonReentrant
        onlyOwner
    {
        IERC20Upgradeable borrowUnderlying = IERC20Upgradeable(borrowToken_);
        IVenusBEP20Delegator borrowDelegator = IVenusBEP20Delegator(
            delegator[borrowToken_]
        );

        // Borrowing
        uint256 borrowableAmount = getUserBorrowableAmount(
            _msgSender(),
            borrowToken_
        );

        require(
            _amount <= borrowableAmount,
            "[DyBEP20BorrowVenus]::Exceed borrowable amount"
        );

        require(
            borrowDelegator.borrow(_amount) == 0,
            "[DyBEP20BorrowVenus]::Borrowing failed"
        );

        borrowUnderlying.transfer(_msgSender(), _amount);

        borrowingAmount[_msgSender()][borrowToken_] += _amount;
        borrowTimestamp[_msgSender()][borrowToken_] = block.timestamp;
    }

    function repay(uint256 _amount, address borrowToken_) public nonReentrant {
        require(
            delegator[borrowToken_] != address(0),
            "[DyBEP20BorrowVenus]::Underlying is not registered."
        );

        IERC20Upgradeable borrowUnderlying = IERC20Upgradeable(borrowToken_);
        IVenusBEP20Delegator borrowDelegator = IVenusBEP20Delegator(
            delegator[borrowToken_]
        );

        uint256 interest = getBorrowInterest(_msgSender(), borrowToken_);
        uint256 totalAmount = interest + _amount;

        // Repay borrowing
        borrowUnderlying.transferFrom(_msgSender(), address(this), _amount);
        borrowUnderlying.approve(address(borrowDelegator), _amount);

        require(
            borrowDelegator.repayBorrow(_amount) == 0,
            "[DyBEP20BorrowVenus]::Repay failed"
        );

        borrowingAmount[_msgSender()][borrowToken_] = borrowingAmount[
            _msgSender()
        ][borrowToken_].sub(_amount);
        borrowTimestamp[_msgSender()][borrowToken_] = block.timestamp;
    }

    function getBorrowBalance(address borrowToken_)
        public
        view
        returns (uint256)
    {
        return borrowingAmount[_msgSender()][borrowToken_];
    }

    function getBorrowableAmount(address borrowToken_)
        public
        view
        returns (uint256)
    {
        IVenusBEP20Delegator borrowDelegator = IVenusBEP20Delegator(
            delegator[borrowToken_]
        );

        (
            uint256 errorCode,
            uint256 borrowableAmountInDollar,
            uint256 shortFall
        ) = rewardController.getAccountLiquidity(address(this));
        require(errorCode == 0, "[DyBEP20BorrowVenus]::Get borrowable failed");
        require(
            shortFall == 0,
            "[DyBEP20BorrowVenus]::Having shortfall account"
        );

        uint256 underlyingPrice = oracle.getUnderlyingPrice(
            delegator[borrowToken_]
        );

        (, uint256 borrowLimit) = rewardController.markets(
            address(borrowDelegator)
        );

        return
            borrowableAmountInDollar
                .mul(underlyingPrice)
                .div(BIPS)
                .mul(borrowLimit)
                .div(BIPS);
    }

    function getUserBorrowableAmount(address user_, address borrowToken_)
        public
        view
        returns (uint256)
    {
        IVenusBEP20Delegator borrowDelegator = IVenusBEP20Delegator(
            delegator[borrowToken_]
        );

        (
            uint256 underlyingInDollars,
            uint256 borrowInDollars
        ) = getUserEquivalentAssetAndBorrow(user_);

        uint256 underlyingPrice = oracle.getUnderlyingPrice(
            delegator[borrowToken_]
        );

        (, uint256 borrowLimit) = rewardController.markets(
            address(borrowDelegator)
        );

        uint256 userBorrowableAmountRaw = underlyingInDollars
            .mul(borrowLimit)
            .div(BIPS)
            .sub(borrowInDollars)
            .mul(underlyingPrice)
            .div(BIPS);
        uint256 borrowableAmountRaw = getBorrowableAmount(borrowToken_);
        if (userBorrowableAmountRaw > borrowableAmountRaw) {
            return borrowableAmountRaw;
        }
        return userBorrowableAmountRaw;
    }

    function getUserEquivalentAssetAndBorrow(address user_)
        public
        view
        returns (uint256, uint256)
    {
        uint256 underlyingInDollars = 0;
        uint256 borrowInDollars = 0;

        for (uint256 i = 0; i < vaults.length; i++) {
            address tokenAddress = vaults[i];
            uint256 tokenPrice = oracle.getUnderlyingPrice(
                delegator[tokenAddress]
            );
            underlyingInDollars = underlyingInDollars.add(
                underlyingBalanceUser[user_][vaults[i]].mul(BIPS).div(
                    tokenPrice
                )
            );
            borrowInDollars = borrowInDollars.add(
                borrowingAmount[user_][vaults[i]].mul(BIPS).div(tokenPrice)
            );
        }

        return (underlyingInDollars, borrowInDollars);
    }

    function getBorrowedAmount(address user_, address borrowToken_)
        public
        view
        returns (uint256)
    {
        return borrowingAmount[user_][borrowToken_];
    }

    function getBorrowInterest(address user_, address borrowToken_)
        public
        view
        returns (uint256)
    {
        uint256 borrowAmount = borrowingAmount[user_][borrowToken_];
        return
            (block.timestamp - borrowTimestamp[user_][borrowToken_])
                .mul(borrowAmount)
                .mul(BorrowAPY[borrowToken_])
                .div(ONE_YEAR_IN_SECOND)
                .div(borrowDivisor);
    }

    function getRedeemableAmount(address underlying_)
        private
        returns (uint256)
    {
        IVenusBEP20Delegator tokenDelegator = IVenusBEP20Delegator(
            delegator[underlying_]
        );
        uint256 underlyingBalance = tokenDelegator.balanceOfUnderlying(
            address(this)
        );
        uint256 borrowed = tokenDelegator.borrowBalanceCurrent(address(this));

        (, uint256 borrowLimit) = rewardController.markets(
            address(tokenDelegator)
        );

        uint256 redeemSafeteMargin = BIPS.mul(990).div(1000);

        if (borrowLimit == 0) {
            return underlyingBalance.mul(redeemSafeteMargin).div(BIPS);
        }
        return
            underlyingBalance
                .sub(borrowed.mul(BIPS).div(borrowLimit))
                .mul(redeemSafeteMargin)
                .div(BIPS);
    }

    function getVaults() public view returns (address[] memory vaults_) {
        vaults_ = new address[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            vaults_[i] = vaults[i];
        }
        return vaults_;
    }

    function getWithdrawableAmount(address user_, address token_)
        public
        view
        returns (uint256, uint256)
    {
        uint256 decimal = getDecimal(token_);
        (
            uint256 underlyingInDollars,
            uint256 borrowInDollars
        ) = getUserEquivalentAssetAndBorrow(user_);

        (uint256 underlyingPrice, uint256 borrowLimit) = getPriceAndBorrowLimit(
            token_
        );

        if (borrowLimit == 0) {
            return (0, borrowInDollars);
        }

        uint256 underlyingBalanceAmount = underlyingBalanceUser[user_][token_];

        uint256 withdrawableAmount = underlyingInDollars
            .sub(borrowInDollars.mul(BIPS).div(borrowLimit))
            .mul(underlyingPrice)
            .div(BIPS)
            .div(10**(36 - 2 * decimal));

        uint256 amount = withdrawableAmount > underlyingBalanceAmount
            ? underlyingBalanceAmount
            : withdrawableAmount;
        return (amount, borrowInDollars);
    }

    function getPriceAndBorrowLimit(address token_)
        public
        view
        returns (uint256, uint256)
    {
        uint256 underlyingPrice = oracle.getUnderlyingPrice(delegator[token_]);

        (, uint256 borrowLimit) = rewardController.markets(delegator[token_]);

        return (underlyingPrice, borrowLimit);
    }

    function setCertainDelegator(address underlying_, address delegator_)
        public
        onlyOwner
    {
        delegator[underlying_] = delegator_;
    }

    function setAsset(address[] memory assets) public onlyOwner {
        vaults = assets;
    }

    function getDecimal(address token_) public view returns (uint256) {
        uint256 decimal = assetDecimals[token_];
        if (decimal == 0) {
            return 18;
        }
        return assetDecimals[token_];
    }

    receive() external payable {}
}