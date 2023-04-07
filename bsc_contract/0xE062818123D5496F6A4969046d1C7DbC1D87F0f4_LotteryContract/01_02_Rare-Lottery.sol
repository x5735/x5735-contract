// SPDX-License-Identifier: GPL-3.0

/** 
*   --------------------About RareAddress-----------------------
*   RareAddress: open source #TRX & #ETH rare address generator.
*   website:   www.rareaddress.io
*
*   --------------------Contact us-----------------------------
*   telegram : t.me/RareAddress
*   twitter:  https://twitter.com/RareAddress_io
*
*    --------------------Lottery Rules-----------------------------
*   RareAddress Lottery Smart Contract
*   1.After every 100 bets, the smart contract will automatically draw prizes
*   2.In this round of lucky draw, sending tokens greater than or equal to 0.01 BNB to this contract address, and you  will automatically qualify for the prize
*   3.Winners will get all prizes from the prize pool, plus rareaddress official rewards
*/


//bsc 已部署合约地址   0xE062818123D5496F6A4969046d1C7DbC1D87F0f4

pragma solidity ^0.8.0;

import "./strings.sol";

contract LotteryContract {

    using strings for *;

    address private lotteryExecutor;

    address[] private players;

    //default minimum bet: 0.001 ether
    uint256 private miniBet=1*(10**16);

    string[] private matchKeys;

    uint private matchLen=4;

    uint private lotteryNum=100;

    uint private count=0;

    string[] keys=['1','2','3','4','5','6','7','8','9','0','a','b','c','d','e','f'];

    constructor(){
        lotteryExecutor=msg.sender;
        initial();
    }

    function initial() private returns(bool){
        delete matchKeys;
        uint len=keys.length;
        for(uint m=0;m<len;m++){
            string memory matchKey;
            for(uint k=0;k<matchLen;k++){
                matchKey=matchKey.toSlice().concat(keys[m].toSlice());
            }
            matchKeys.push(matchKey);
        }
        return true;
    }

    modifier onlyExecutor() {
        require(lotteryExecutor == msg.sender, "caller is not the Lottery Executor");
        _;
    }

    function lottery() public onlyExecutor{
        uint index = generateRandom() % players.length;
        payable(players[index]).transfer(address(this).balance);

        players = new address[](0);
        count=0;
    }

    function generateRandom() private view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, players)));
    }

    receive() external payable {
        require(msg.value>=miniBet,"Minimum bet not met");
        strings.slice memory addrSlice=toString(msg.sender).toSlice();

        bool matched;
        for(uint m=0;m<matchKeys.length;m++){
            if(addrSlice.contains(matchKeys[m].toSlice())){
                players.push(msg.sender);
                matched=true;
                break;
            }
        }

        require(matched,"The player's address does not match the rules.");
        count++;
        if(count>=lotteryNum){
            lottery();
        }
    }

    function toString(address account) private pure returns (string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(bytes memory data) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function updateMatchLenAndInitial(uint _newMatchLen) private  returns (bool) {
        require(matchLen!=_newMatchLen && _newMatchLen>=3);
        matchLen=_newMatchLen;
        initial();
        return true;
    }

    function updateMiniBet(uint256 _newMiniBet) public returns (bool) {
        require(miniBet!=_newMiniBet && _newMiniBet>0);
        miniBet=_newMiniBet;
        return true;
    }

    function updateLotteryNum(uint _newLotteryNum) public returns (bool) {
        require(lotteryNum!=_newLotteryNum && _newLotteryNum>0);
        lotteryNum=_newLotteryNum;
        return true;
    }

    function getMatchLen() public view returns (uint) {
        return matchLen;
    }

    function getLotteryNum() public view returns (uint) {
        return lotteryNum;
    }

    function getMiniBet() public view returns (uint) {
        return miniBet;
    }

    function getPlayers() public view returns(address[] memory) {
        return players;
    }

    function getMatchKeys() public view returns(string[] memory){
        return matchKeys;
    }

}