// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../Libraries/Utils.sol";
import "../Interfaces/IEventDispatcher.sol";

contract SmartWallet {
	address public EVENT_DISPATCHER;
	address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
	address public owner;

	constructor(address newOwner, address _eventDispatcher) {
		EVENT_DISPATCHER = _eventDispatcher;
		_transferOwnership(newOwner);
	}

	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	function _transferOwnership(address newOwner) internal virtual {
		owner = newOwner;
	}

	function simulateTransaction(
		Utils.IpramsSimulateTransaction memory params
	) external onlyOwner returns (bool, bytes memory) {
		(bool success, bytes memory data) = params.toAddress.call{value: params.value}(params.data);
		require(success, "call failed");
		return (success, data);
	}

	function execute(Utils.Iparams memory params, bytes memory signature) public returns (bool, bytes memory) {
		require(address(this) == params.fromAddress, 'wrong "from" param');

		IEventDispatcher(EVENT_DISPATCHER).executeIntent(params, signature);

		(bool success, bytes memory data) = params.toAddress.call{value: params.value}(params.data);
		require(success, "call failed");
		return (success, data);
	}

	function withdraw(address _token, uint256 _amount) external onlyOwner {
		IERC20(_token).transfer(msg.sender, _amount);
	}

	function transferNFT(address nft, address to, uint256 tokenId) external onlyOwner {
		IERC721(nft).safeTransferFrom(address(this), to, tokenId);
	}

	function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
		return IERC721Receiver.onERC721Received.selector;
	}

	event Received(address, uint256);

	receive() external payable {
		emit Received(msg.sender, msg.value);
	}
}