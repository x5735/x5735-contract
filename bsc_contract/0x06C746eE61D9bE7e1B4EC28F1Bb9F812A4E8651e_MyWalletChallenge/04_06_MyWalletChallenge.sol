// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyProxy.sol";
import "./Wallet.sol";

contract MyWalletChallenge is Ownable {
    mapping(address => address) public walletMap;
    mapping(address => bool) public challenged;


    modifier onlyChallenger() {
        require(walletMap[msg.sender] != address(0), "only challenger");
        require(!challenged[msg.sender], "already challenged 1");
        _;
    }

    modifier onlyNotRegister() {
        require(walletMap[msg.sender] == address(0), "already register");
        _;
    }

    receive() external payable {}

    function close() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function register() external onlyNotRegister returns (address) {
        Wallet impl = new Wallet();
        MyProxy wallet = new MyProxy(address(impl), address(this), "");
        address payable walletAddress = payable(address(wallet));
        Wallet(walletAddress).initialize();

        walletMap[msg.sender] = walletAddress;
        (bool success, ) = walletAddress.call{ gas: 5000, value: 0.1 ether }("");
        require(success, "walletAddress init transfer failed");

        return walletAddress;
    }
}