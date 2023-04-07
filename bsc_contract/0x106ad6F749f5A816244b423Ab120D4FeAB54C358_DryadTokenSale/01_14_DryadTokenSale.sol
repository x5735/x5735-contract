// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./DryadToken.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/*
    TODO: Token price para fiat y crypto tienen que ser diferentes
    TODO: Como generar un ratio para convertir USD a BNB

*/
contract DryadTokenSale is Pausable, AccessControl {
    uint8 public constant DECIMALS = 18;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    struct TokenSaleProperties {
        address payable admin;
        address icoContractAddress;
        uint256 tokenPrice;
        uint256 tokenPriceBNB;
        uint256 tokensSold;
        uint256 tokenSupply;
        string icoPhase;
        bool paused;
    }
    TokenSaleProperties private properties;
    DryadToken public tokenContract;

    event Sell(address indexed buyer, uint256 amount);
    event AddedTokenSupply(address indexed minter, uint256 amount);

    constructor(
        DryadToken _tokenContract,
        uint256 _tokenPrice,
        string memory _icoPhase,
        bool _paused
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        tokenContract = _tokenContract;
        properties.tokenPrice = _tokenPrice;
        properties.icoPhase = _icoPhase;
        properties.paused = _paused;
        properties.admin = payable(msg.sender);
        properties.tokensSold = 0;
        properties.tokenSupply = 0;
        properties.tokenPriceBNB = 0; 
        properties.icoContractAddress = address(this);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function changeICOPhase(
        string memory _icoPhase
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        properties.icoPhase = _icoPhase;
    }

    function changeICOTokenPrice(
        uint256 _tokenPrice
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        properties.tokenPrice = _tokenPrice;
    }
    function changeICOTokenPriceBNB(
        uint256 _tokenPrice
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        properties.tokenPriceBNB = _tokenPrice;
    }

    function getTokenPrice() public view returns (uint256) {
        return properties.tokenPrice;
    }

    function addICOTokenSupply(uint256 _amount) public {
        properties.tokenSupply = _amount;
        emit AddedTokenSupply(msg.sender, _amount);
    }

    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function buyTokensFiat(
        address _receiver,
        uint256 _numberOfTokens
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenContract.balanceOf(address(this)) >= _numberOfTokens);
        require(tokenContract.transfer(msg.sender, _numberOfTokens));

        properties.tokensSold += _numberOfTokens;

        emit Sell(_receiver, _numberOfTokens);
    }

    function buyTokens(uint256 _numberOfTokens) public payable {
        require(properties.tokenPriceBNB>0);
        require(msg.value == multiply(_numberOfTokens, properties.tokenPriceBNB));
        require(tokenContract.balanceOf(address(this)) >= _numberOfTokens);
        require(tokenContract.transfer(msg.sender, _numberOfTokens));

        properties.tokensSold += _numberOfTokens;

        emit Sell(msg.sender, _numberOfTokens);
    }

    function getTokensSold() public view returns (uint256) {
        return properties.tokensSold;
    }

    function getICOTokenSupply() public view returns (uint256) {
        return properties.tokenSupply;
    }

    function getICOTokenPhase() public view returns (string memory) {
        return properties.icoPhase;
    }

    function stopICO() public onlyRole(DEFAULT_ADMIN_ROLE) {
        properties.tokenPrice = 0;
        properties.tokensSold = 0;
        properties.tokenSupply = 0;
        endSale();
    }

    function endSale() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            tokenContract.transfer(
                properties.admin,
                tokenContract.balanceOf(address(this))
            )
        );
        properties.admin.transfer(address(this).balance);
    }
}