//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import "AggregatorV3Interface.sol";
import "SafeERC20.sol";

interface PreSale {
    function pauseByPreSale(address sender) external;

    function burnByPreSale(uint256 amount) external;
}

contract MGUPreSale {
    constructor() {
        owner = payable(msg.sender);
    }

    /**
     *@dev sets The MGU Token Contract Address.
     */
    IERC20 token;
    address tokenAddress;
    address payable public owner;
    uint256 private balance;
    uint256 constant _preSaleAmount = 234_000_000 * 10 ** 18;
    event preSaleSent(address _from, address _to, uint256 amount);
    event transferReceived(address _from, uint256 amount);
    /**
     *@dev sets MIN and MAX BNB Amount for Purchasing MGU at Preslae.
     */
    uint256 private minValue = 5 * 10 ** 16;
    uint256 private maxValue = 10 * 10 ** 18;

    /**
     *@dev sets the MGU Token Price equivalent in wei format.
     */
    uint256 private tkPriceInWei = 1 * 10 ** 16;

    /**
     *@dev sets the start,end and burning time for presale.
     */
    uint256 private _startAt;
    uint256 private _endAt;
    uint256 private _burnAt;
    /**
     *@dev keep track of whitelist address state,amount and claim states
     */
    mapping(address => uint256) private whitelisted;
    mapping(address => bool) private _iswhitelisted;

    /**
     *@dev chainlink's contract base Realtime BNBUSD PriceFeed.
     */
    address BNBUSD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    function burnPresaleRemainingToken() external onlyOwner {
        require(_burnAt > 0, "Burn Date Not Set!");
        require(
            block.timestamp > _burnAt,
            "Admin:Not Allowed.The time of burning process has not arrived"
        );
        PreSale(tokenAddress).burnByPreSale(token.balanceOf(address(this)));
    }

    // modifiers:
    modifier onlyOwner() {
        require(msg.sender == owner, "Not Allowed!");
        _;
    }
    modifier inPreSlaeTime() {
        require(block.timestamp >= _startAt, "PreSale Not Started Yet!");
        require(block.timestamp <= _endAt, "PreSale Ended!");
        _;
    }
    modifier isPresaleEnded() {
        require(_startAt > 0, "Presale Not set!");
        require(block.timestamp > (_startAt + 45 days), "Presale Not Ended");
        _;
    }

    // setters:
    /**
     *@dev Sets Presale Start date and also End date. callable by onlyOwner.
     *@param _startTime presale start time.
     */
    function setPresaleStartEnd(uint256 _startTime) external onlyOwner {
        _startAt = _startTime;
        _endAt = _startTime + 45 days;
        _burnAt = _startTime + 75 days;
    }

    receive() external payable {
        balance += msg.value;
        emit transferReceived(msg.sender, msg.value);
    }

    /**
     *@dev Sets Presale Token Contract Address. callable by onlyOwner.
     *@param tokenContractAddress MGU Token Contract Address.
     */
    function setToken(
        IERC20 tokenContractAddress,
        address tokenaddress_
    ) external onlyOwner returns (bool) {
        token = tokenContractAddress;
        tokenAddress = tokenaddress_;
        return true;
    }

    function setWhiteList(
        address[] memory Addresses,
        uint256[] memory Amounts
    ) external onlyOwner returns (bool) {
        require(
            Addresses.length == Amounts.length,
            "Addresses'length with Amounts's length Not Mached!"
        );
        for (uint256 i = 0; i < Addresses.length; i++) {
            whitelisted[Addresses[i]] = (Amounts[i] * 10 ** 18);
            _iswhitelisted[Addresses[i]] = true;
        }
        return true;
    }

    function claimMGU() external payable isPresaleEnded {
        require(_iswhitelisted[msg.sender], "You Are Not in Whitelist");
        require(whitelisted[msg.sender] > 0, "You Claimed before!");
        require(
            token.balanceOf(address(this)) - whitelisted[msg.sender] >= 0,
            "No More Token Exists For Claim.Presale Amount Reached MaxCap!"
        );
        token.transfer(msg.sender, whitelisted[msg.sender]);
        whitelisted[msg.sender] = 0;
    }

    function iswhitelisted(address recipient) external view returns (bool) {
        return _iswhitelisted[recipient];
    }

    /**
     *@dev returns equivallent amount of MGU for BNB value.
     *@param value msg.sender's BNB value.
     */
    function getamount(uint256 value) public view returns (uint256) {
        uint256 price = (getPrice() * value) / 10 ** 8;
        return (price / (tkPriceInWei)) * 10 ** 18;
    }

    /**
     *@dev trigger when purchaser wants to buy MGU.
     *     1-calls getamount function to calculate MGU amount
     *     2-calls transferPresale function to mint amount token
     *     3-subtract amount from remainingtoken
     */
    function preSaleFund() external payable inPreSlaeTime {
        require(msg.value >= minValue, "Minimun Amount Exception!");
        require(msg.value <= maxValue, "Maximun Amount Exception!");
        uint256 amount = getamount(msg.value);
        require(
            token.balanceOf(address(this)) - (amount) >= 0,
            "there is nothing to fund"
        );
        token.transfer(msg.sender, amount);
        PreSale(tokenAddress).pauseByPreSale(msg.sender);
        emit preSaleSent(address(this), msg.sender, amount);
    }

    // getters:

    /**
     *@dev returns presale start and end time.
     */
    function getPresaleTime() external view returns (uint256, uint256) {
        return (_startAt, _endAt);
    }

    function getClaimTime() external view returns (uint256, uint256) {
        return (_endAt, _endAt + 30 days);
    }

    /**
     *@dev returns BNB Realtime Price in wei format
     */
    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(BNBUSD);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    /**
     *@dev returns MGU Token contract address.
     */
    function getTokenContract() external view returns (IERC20) {
        return token;
    }

    function gettokenbalance(IERC20 erc20token) public view returns (uint256) {
        return erc20token.balanceOf(address(this));
    }

    /**
     *@dev withdrow Funds to Owner. callable by onlyOwner.
     */
    function withdraw() external payable onlyOwner {
        (bool os, ) = msg.sender.call{value: address(this).balance}("");
        require(os);
    }
}