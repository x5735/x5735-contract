// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "MyToken.sol";
//./../node_modules/
import "AccessControl.sol";
import "Ownable.sol";
import "Pausable.sol";
import "ReentrancyGuard.sol";
import "ECDSA.sol";
import "SignatureChecker.sol";

contract MyTokenSale is Ownable, Pausable, AccessControl, ReentrancyGuard {
    MyToken public token;
    uint256 public tokenPrice;
    uint256 public BUY_FEE_PERCENTAGE;
    uint256 public SELL_FEE_PERCENTAGE;
    address public marketingWallet;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public maxBuyTokens;
    uint256 public maxSellTokens;
    uint256 public saleEndTime;

    constructor(
        address _token,
        uint256 _tokenPrice,
        uint256 _buy_fee,
        uint256 _sell_fee,
        address _marketingWallet,
        uint256 _maxBuyTokens,
        uint256 _maxSellTokens
    ) {
        token = MyToken(_token);
        tokenPrice = _tokenPrice;
        marketingWallet = _marketingWallet;

        BUY_FEE_PERCENTAGE = _buy_fee;
        SELL_FEE_PERCENTAGE = _sell_fee;

        maxBuyTokens = _maxBuyTokens;
        maxSellTokens = _maxSellTokens;

        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function calculateEthForTokens(
        uint256 _amount,
        uint256 _tax,
        bool _down
    ) public view returns (uint256, uint256, uint256) {
        uint256 fee = (_amount * _tax) / 100;
        uint256 amountWithFee = _amount + fee;
        if (_down == true) amountWithFee = _amount - fee;
        uint256 eth = amountWithFee * tokenPrice;

        return (fee, amountWithFee, eth);
    }

    event TokensPurchased(address buyer, uint256 amount);

    function buyTokens(uint256 _amount) public payable whenNotPaused {
        require(_amount > 0, "Token amount must be greater than 0");
        require(_amount <= maxBuyTokens, "Exceeds max token buy limit");

        (
            uint256 fee,
            uint256 amountWithFee,
            uint256 eth
        ) = calculateEthForTokens(_amount, BUY_FEE_PERCENTAGE, false);
        require(
            saleEndTime == 0 || block.timestamp <= saleEndTime,
            "Sale has ended"
        ); // Check if sale has ended
        require(msg.value == eth, "Incorrect Ether amount");

        uint256 total_token_amount = token.getTokensAsMinimum(amountWithFee);
        require(
            token.balanceOf(address(this)) >= total_token_amount,
            "Insufficient token balance in contract"
        );
        uint256 sender_token_amount = token.getTokensAsMinimum(_amount);
        token.transfer(msg.sender, sender_token_amount);

        // Enviar fee a la direcci¨®n de marketing
        uint256 feeAmount = token.getTokensAsMinimum(fee);
        require(
            marketingWallet != msg.sender && marketingWallet != address(0),
            "Invalid marketing wallet address"
        );
        token.transfer(marketingWallet, feeAmount);

        emit TokensPurchased(msg.sender, total_token_amount);
    }

    event TokensSold(address seller, uint256 amount, uint256 eth);

    function sellTokens(uint256 _amount) public whenNotPaused {
        require(_amount > 0, "Token amount must be greater than 0");
        require(_amount <= maxSellTokens, "Exceeds max token buy limit");

        (uint256 fee, , uint256 eth) = calculateEthForTokens(
            _amount,
            SELL_FEE_PERCENTAGE,
            true
        );

        _amount = token.getTokensAsMinimum(_amount);

        require(
            token.balanceOf(msg.sender) >= _amount,
            "Insufficient token balance for seller"
        );

        token.transferFrom(msg.sender, address(this), _amount);

        // Enviar fee a la direcci¨®n de marketing
        uint256 feeAmount = token.getTokensAsMinimum(fee);
        require(
            marketingWallet != msg.sender && marketingWallet != address(0),
            "Invalid marketing wallet address"
        );
        token.transfer(marketingWallet, feeAmount);

        // Enviar Ether al vendedor
        address payable seller = payable(msg.sender);
        seller.transfer(eth);

        emit TokensSold(msg.sender, _amount, eth);
    }

    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient token balance in contract"
        );
        token.transfer(msg.sender, _amount);
    }

    function withdrawEther(uint256 _amount) external onlyOwner {
        require(
            address(this).balance >= _amount,
            "Insufficient Ether balance in contract"
        );
        payable(owner()).transfer(_amount);
    }

    event TokenPriceUpdated(uint256 oldPrice, uint256 newPrice);

    function setTokenPrice(uint256 _newPrice) external onlyRole(ADMIN_ROLE) {
        emit TokenPriceUpdated(tokenPrice, _newPrice);
        tokenPrice = _newPrice;
    }

    event MarketingWalletUpdated(address oldWallet, address newWallet);

    function setMarketingWallet(
        address _newMarketingWallet
    ) external onlyRole(ADMIN_ROLE) {
        emit MarketingWalletUpdated(marketingWallet, _newMarketingWallet);
        marketingWallet = _newMarketingWallet;
    }

    function setSaleEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime > block.timestamp, "End time must be in the future");
        saleEndTime = _endTime;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function grantAdminRole(address account) public onlyOwner {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyOwner {
        revokeRole(ADMIN_ROLE, account);
    }
}