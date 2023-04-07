//SPDX-License-Identifier:MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./IERC20.sol";

/**
 * @title TicketSystemCD
 * @author karan (@cryptofluencerr, https://cryptofluencerr.com)
 * @dev The TicketSystemCD contract is used for purchasing tickets for CryptoDuels.
 */

contract TicketSystemCD is Ownable, ReentrancyGuard, Pausable {
    IUniswapV2Router02 public pancakeRouter;

    //============== VARIABLES ==============
    IERC20 public GQToken;
    uint256 public ticketPrice;
    uint256 public teamPercentage;
    uint256 public rewardPoolPercentage;
    uint256 public burnPercentage;
    uint256 public withdrawLimit;
    uint256 public OZFees;
    address public pancakeRouterAddress;

    address public teamAddress;
    address public rewardPool;
    address public admin;
    uint256 decimals;

    address private pairAddress;

    struct UserInfo {
        uint256 ticketBalance;
        uint256 lastWithdrawalTime;
    }

    //============== MAPPINGS ==============
    mapping(address => UserInfo) public userInfo;

    //============== EVENTS ==============
    event TicketPurchased(
        address indexed buyer,
        uint256 numofTicket,
        uint256 amountPaid
    );
    event TicketWithdrawn(
        address indexed user,
        uint256 numOfTicket,
        uint256 amountRefund
    );
    event FeesTransfered(
        uint256 teamAmount,
        uint256 rewardPoolAmount,
        uint256 burnAmount
    );
    event TokenWithdrawn(address indexed owner, uint256 amount);
    event SetUserBalance(address indexed user, uint256 amount);
    event SetTokenAddress(address tokenAddr);
    event SetPairAddress(address pairAddr);
    event SetTicketprice(uint256 price);
    event SetTeamPercentage(uint256 teamPercent);
    event SetRewardPoolPercentage(uint256 rewardPoolPercent);
    event SetBurnPercentage(uint256 burnPercent);
    event SetWithdrawLimit(uint256 withdrawLimit);
    event SetOZFees(uint256 OZFees);
    event SetTeamAddress(address teamAddr);
    event SetRewardAddress(address rewardPoolAddr);
    event SetAdmin(address newAdmin);
    event SetRouterAddress(address _routerAddress);

    //============== CONSTRUCTOR ==============
    constructor() {
        decimals = 10 ** 18;
        ticketPrice = 1 * decimals;
        teamPercentage = (ticketPrice * 1000) / 10000;
        rewardPoolPercentage = (ticketPrice * 250) / 10000;
        burnPercentage = (ticketPrice * 250) / 10000;
        withdrawLimit = 500 * decimals;
        OZFees = (2500 * decimals) / 10000;

        // mainnet
        pancakeRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        pancakeRouter = IUniswapV2Router02(pancakeRouterAddress);
        GQToken = IERC20(0xF700D4c708C2be1463E355F337603183D20E0808);
        pairAddress = 0x72121d60b0e2F01c0FB7FE32cA24021b42165A40;
        admin = 0xbb1220Eb122f85aE0FAf61D89e0727C4962b4506;
        teamAddress = 0x81319B34e571d8aE7725bD611bcB8c0b3556bF01;
        rewardPool = 0x81319B34e571d8aE7725bD611bcB8c0b3556bF01;

        // testnet
        // pancakeRouterAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
        // pancakeRouter = IUniswapV2Router02(pancakeRouterAddress);
        // GQToken = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
        // admin = 0xDb3360F0a406Aa9fBbBd332Fdf64ADb688e9a769;
        // pairAddress = 0x209eBd953FA5e3fE1375f7Dd0a848A9621e9eaFc;
        // teamAddress = 0xDb3360F0a406Aa9fBbBd332Fdf64ADb688e9a769;
        // rewardPool = 0xDb3360F0a406Aa9fBbBd332Fdf64ADb688e9a769;
    }

    //============== MODIFIER ==============
    /**
     * @dev Modifier to ensure only the admin can call the function
     */
    modifier onlyAdmin() {
        require(_msgSender() == admin, "Only admin");
        _;
    }

    //============== VIEW FUNCTIONS ==============
    /**
     * @dev Function to get GQ price from Pancackeswap
     */
    function getPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        return (uint256(reserve1) * decimals) / uint256(reserve0);
    }

    //============== EXTERNAL FUNCTIONS ==============
    /**
     * @dev Function to Purchase Tickets
     * @param numOfTicket to select quantity of tickets to purchase
     */
    function purchaseTicket(
        uint256 numOfTicket
    ) external payable whenNotPaused nonReentrant {
        require(
            numOfTicket > 0,
            "Purchase Ticket: Number of Ticket should be greater than Zero"
        );
        uint256 amount;
        uint256 ticketAmount = (numOfTicket * ticketPrice) / decimals;
        uint256 teamAmount = (numOfTicket * teamPercentage) / decimals;
        uint256 rewardPoolAmount = (numOfTicket * rewardPoolPercentage) /
            decimals;
        uint256 burnAmount = (numOfTicket * burnPercentage) / decimals;
        uint256 ozFees = (OZFees * 1e18) / decimals;

        amount =
            ticketAmount +
            teamAmount +
            rewardPoolAmount +
            burnAmount +
            ozFees;

        bool success = GQToken.transferFrom(
            _msgSender(),
            address(this),
            amount
        );
        require(success, "Purchase Ticket: GQ transfer failed.");
        feesTransfer(teamAmount, rewardPoolAmount, burnAmount);

        swapTokensForEth(ozFees);
        uint256 BNBBalance = address(this).balance;
        (bool BNBSuccess, ) = admin.call{value: BNBBalance}("");
        require(BNBSuccess, "Purchase Ticket: BNB transfer failed.");

        userInfo[_msgSender()].ticketBalance += numOfTicket;

        emit TicketPurchased(_msgSender(), numOfTicket, amount);
    }

    /**
     * @dev Function to Withdraw Tickets
     * @param numOfTicket to select quantity of tickets to withdraw
     */
    function withdrawTicket(
        uint256 numOfTicket
    ) external whenNotPaused nonReentrant {
        require(
            userInfo[_msgSender()].ticketBalance >= numOfTicket,
            "Withdraw Ticket: Insufficient Balance"
        );
        require(
            numOfTicket >= 1,
            "Withdraw Ticket: Amount should be greater than Zero"
        );
        if (userInfo[_msgSender()].lastWithdrawalTime != 0) {
            require(
                userInfo[_msgSender()].lastWithdrawalTime + 24 hours <=
                    block.timestamp,
                "Withdraw Ticket: Withdrawal is only allowed once every 24 hours"
            );
        }

        uint256 amount = (numOfTicket * ticketPrice) / decimals;
        uint256 teamAmount = (numOfTicket * teamPercentage) / decimals;
        uint256 rewardPoolAmount = (numOfTicket * rewardPoolPercentage) /
            decimals;
        uint256 burnAmount = (numOfTicket * burnPercentage) / decimals;

        uint256 balance = GQToken.balanceOf(address(this));
        require(
            balance >= amount,
            "Withdraw Ticket: Not enough balance in the contract"
        );
        require(
            amount <= (withdrawLimit * getPrice()) / decimals,
            "Withdraw Ticket: Withdrawal amount exceeds Limit"
        );

        uint256 ticketAmount = amount -
            (teamAmount + rewardPoolAmount + burnAmount);

        userInfo[_msgSender()].lastWithdrawalTime = block.timestamp;
        userInfo[_msgSender()].ticketBalance -= numOfTicket;

        bool success = GQToken.transfer(_msgSender(), ticketAmount);
        require(success, "Withdraw Ticket: Return Failed");

        feesTransfer(teamAmount, rewardPoolAmount, burnAmount);

        emit TicketWithdrawn(_msgSender(), numOfTicket, ticketAmount);
    }

    /**
     * @notice swaps dedicated amount from GQ -> BNB
     * @param amount total GQ amount that need to be swapped to BNB
     */
    function swapTokensForEth(uint256 amount) private {
        // Generate the uniswap pair path of GQToken -> weth
        address[] memory path = new address[](2);
        path[0] = address(GQToken);
        path[1] = pancakeRouter.WETH();

        GQToken.approve(address(pancakeRouter), amount);

        pancakeRouter.swapExactTokensForETH(
            amount,
            0,
            path,
            address(this), // this contract will receive the eth that were swapped from the GQToken
            block.timestamp
        );
    }

    /**
     * @notice will set the router address
     * @param _routerAddress pancake router address
     */
    function setRouterAddress(address _routerAddress) external onlyOwner {
        require(
            _routerAddress != address(0),
            "Set Router Address: Invalid router address"
        );
        pancakeRouterAddress = _routerAddress;
        pancakeRouter = IUniswapV2Router02(_routerAddress);
        emit SetRouterAddress(_routerAddress);
    }

    /**
     * @dev Function to Withdraw funds
     */
    function withdraw() external onlyOwner {
        uint256 balance = GQToken.balanceOf(address(this));
        require(balance > 0, "Withdraw: Not enough balance in the contract");
        bool success;
        success = GQToken.transfer(owner(), balance);
        require(success, "Withdraw: Withdraw Failed");
        emit TokenWithdrawn(owner(), balance);
    }

    /**
     * @dev Function to set the user's ticket balance
     * @param user address of user whose balance is to be set
     * @param amount The balance change amount to be set
     */
    function setUserBalance(
        address user,
        uint256 amount
    ) external onlyAdmin whenNotPaused nonReentrant {
        require(user != address(0), "Set User Balance: Invalid user address");
        userInfo[user].ticketBalance = amount;
        emit SetUserBalance(user, amount);
    }

    /**
     * @dev Function to set the admin address
     * @param newAdmin The new address to set as the admin
     */
    function setAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Set Admin: Invalid address");
        admin = newAdmin;
        emit SetAdmin(admin);
    }

    /**
     * @dev Function to set the new GQToken address that is used Purchasing tickets
     * @param tokenAdd The new GQToken address
     */
    function setTokenAddress(address tokenAdd) external onlyOwner {
        require(tokenAdd != address(0), "Set Token Address: Invalid address");
        GQToken = IERC20(tokenAdd);
        emit SetTokenAddress(tokenAdd);
    }

    /**
     * @dev Function to set the new Pair address of GQToken pool
     * @param pairAdd The new pair address
     */
    function setPairAddress(address pairAdd) external onlyOwner {
        require(pairAdd != address(0), "Set Pair Address: Invalid address");
        pairAddress = pairAdd;
        emit SetPairAddress(pairAdd);
    }

    /**
     * @dev Function to set the Ticket Price
     * @param newPrice The new tick price in wei for 1 ticket.
     */
    function setTicketPrice(uint256 newPrice) external onlyOwner {
        require(
            newPrice > 0,
            "Set Ticket Price: New Price should be greater than Zero"
        );
        ticketPrice = newPrice;
        emit SetTicketprice(newPrice);
    }

    /**
     * @dev Function to set the Ticket OpenZepellin Fees.
     * @param amount The new limit amount in wei.
     */
    function setOZFees(uint256 amount) external onlyOwner {
        require(amount > 0, "Set OZ Fees: OZ Fees be greater than Zero");
        OZFees = amount;
        emit SetOZFees(amount);
    }

    /**
     * @dev Function to set the Ticket withdraw limit.
     * @param amount The new limit amount in wei.
     */
    function setWithdrawLimit(uint256 amount) external onlyOwner {
        require(
            amount > 0,
            "Set Withdraw limit: Withdraw limit be greater than Zero"
        );
        withdrawLimit = amount;
        emit SetWithdrawLimit(amount);
    }

    /**
     * @dev Function to set amount that will be transfered to Team
     * @param amount The new team share amount in wei for 1 ticket price
     */
    function setTeamPercentage(uint256 amount) external onlyOwner {
        teamPercentage = amount;
        emit SetTeamPercentage(amount);
    }

    /**
     * @dev Function to set amount that will be transfered to Reward pool
     * @param amount The new reward pool share amount in wei for 1 ticket price
     */
    function setRewardPoolPercentage(uint256 amount) external onlyOwner {
        rewardPoolPercentage = amount;
        emit SetRewardPoolPercentage(amount);
    }

    /**
     * @dev Function to set GQToken amount that will be burned.
     * @param amount The new burn share amount in wei for 1 ticket price
     */
    function setBurnPercentage(uint256 amount) external onlyOwner {
        burnPercentage = amount;
        emit SetBurnPercentage(amount);
    }

    /**
     * @dev Function to set the Team address
     * @param newTeamAddress The new address to set as the Team address
     */
    function setTeamAddress(address newTeamAddress) external onlyOwner {
        require(
            newTeamAddress != address(0),
            "Set Team Address: Invalid address"
        );
        teamAddress = newTeamAddress;
        emit SetTeamAddress(teamAddress);
    }

    /**
     * @dev Function to set the admin address
     * @param newRewardPoolAddress The new address to set as the Rewardpool address
     */
    function setRewardAddress(address newRewardPoolAddress) external onlyOwner {
        require(
            newRewardPoolAddress != address(0),
            "Set Reward Address: Invalid address"
        );
        rewardPool = newRewardPoolAddress;
        emit SetRewardAddress(rewardPool);
    }

    /**
     * @notice Pauses the contract.
     * @dev This function can only be called by the contract owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     * @dev This function can only be called by the contract owner.
     */
    function unPause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Internal function to transfer the fees.
     * @param teamAmnt amount to transfer to team.
     * @param rewardPoolAmnt amount to transfer to reward pool.
     * @param burnAmnt amount to burn tokens.
     */
    function feesTransfer(
        uint256 teamAmnt,
        uint256 rewardPoolAmnt,
        uint256 burnAmnt
    ) internal {
        bool teamTransfer = GQToken.transfer(teamAddress, teamAmnt);
        require(teamTransfer, "Fees Tramsfer: Team transfer failed");

        bool rewardPoolTransfer = GQToken.transfer(rewardPool, rewardPoolAmnt);
        require(
            rewardPoolTransfer,
            "Fees Transfer: RewardPool transfer failed"
        );

        bool burnTransfer = GQToken.burn(burnAmnt);
        require(burnTransfer, "Fees Transfer: Burn failed");

        emit FeesTransfered(teamAmnt, rewardPoolAmnt, burnAmnt);
    }

    receive() external payable {}
}