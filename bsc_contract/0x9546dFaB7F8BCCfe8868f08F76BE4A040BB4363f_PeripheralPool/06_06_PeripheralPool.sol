// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PeripheralPool is Ownable {
	address public eventDispatcher;
	address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

	function setEventDispatcher(address _eventDispatcher) external onlyOwner {
		eventDispatcher = _eventDispatcher;
	}

	modifier onlyEventDispatcher() {
		require(msg.sender == eventDispatcher);
		_;
	}

	function transferTo(address tokenAddress, address toAddress, uint256 amount) external onlyEventDispatcher {
		if (amount > 0) {
			if (tokenAddress == ETH_ADDRESS) {
				(bool result, ) = toAddress.call{value: amount, gas: 10000}("");
				require(result, "Failed to transter Ether ");
			} else {
				IERC20(tokenAddress).transfer(toAddress, amount);
			}
		}
	}

	function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
		IERC20(_token).transfer(msg.sender, _amount);
	}

	event Received(address, uint256);

	receive() external payable {
		emit Received(msg.sender, msg.value);
	}
}