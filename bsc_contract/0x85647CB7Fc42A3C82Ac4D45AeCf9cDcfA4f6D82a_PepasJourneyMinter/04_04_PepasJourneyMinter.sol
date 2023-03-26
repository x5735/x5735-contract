// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";


interface IPepasJourney {
    function mint(
        address _to,
        uint8 _pepaId
    ) external returns (uint256);
}

contract PepasJourneyMinter is Ownable {

    // Pepa's Journey NFT
    IPepasJourney immutable public pepasJourney;

    // Map the price for each pepaId
    mapping(uint8 => uint256) public price;

    // Map the currently minted supply for each pepaId
    mapping(uint8 => uint256) public minted;

    // Map the max mintable supply for each pepaId
    mapping(uint8 => uint256) public supply;

    // Map the minting state for each pepaId
    mapping(uint8 => bool) public mintActive;


    constructor(address _pepasJourney) {
        pepasJourney = IPepasJourney(_pepasJourney);
    }

    /**
     * @dev Mint pepa with specified pepaId
     */
    function mint(uint8 _pepaId) external payable {
        require(mintActive[_pepaId], "Mint not started yet");
        require(minted[_pepaId] < supply[_pepaId], "All editions minted");
        require(msg.value == price[_pepaId], "Invalid value sent");
        
        minted[_pepaId] += 1;

        pepasJourney.mint(msg.sender, _pepaId);
    }

    /**
     * @dev Configure mint for specified pepaId
     */
    function configureMint(uint8 _pepaId, uint256 _price, uint256 _supply) external onlyOwner {
        require(minted[_pepaId] <= _supply, "Invalid supply");
        supply[_pepaId] = _supply;
        price[_pepaId] = _price;
    }

    /**
     * @dev Set mint status for specified pepaId
     */
    function setMintActive(uint8 _pepaId, bool _mintActive) external onlyOwner {
        mintActive[_pepaId] = _mintActive;
    }

    /**
     * @dev Withdraw all minting funds
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(msg.sender), balance);
    }
}