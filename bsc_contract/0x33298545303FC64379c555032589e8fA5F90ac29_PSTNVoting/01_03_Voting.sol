// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";

contract PSTNVoting is Ownable {
	
	bool public started;
	uint256 public totalVotes;
	
    mapping(address => uint256) public Users;
	mapping(uint256 => uint256) private Answers;

	IRace private immutable race = IRace(address(0xbd6e5D331A09fb39D28CB76510ae9b7d7781aE68));
	
    function vote(uint256 option) external {
		require(started, "not started");

		(uint256 deposits,) = race.usersRealDeposits(msg.sender);
		require(deposits > 1, "not in race or amount too small");

		require(option == 1 || option == 2, "invalid data");
		require(Users[msg.sender] == 0, "already voted");
		
		Users[msg.sender] = option;
		Answers[option]++;
		totalVotes++;
    }

	/* setters */
	function setStarted(bool _value) external onlyOwner{
		started = _value;
	}

	/* getters */	
	function getUserAnswer(address _addr) external view returns (uint256) {
		return Users[_addr];
	}

	function getTotalAnswers(uint256 option) external view returns (uint256) {
		return Answers[option];
	}

	function getWalletStatus(address _value) external view returns (bool) {
		(uint256 deposits,) = race.usersRealDeposits(_value);

		return deposits > 1;
	}
	
}

interface IRace {
    function usersRealDeposits(address _addr) external view returns(uint256 deposits, uint256 deposits_BUSD);
}