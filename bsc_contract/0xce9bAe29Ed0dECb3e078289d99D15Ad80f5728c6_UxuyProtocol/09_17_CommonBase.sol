//SPDX-License-Identifier: UXUY
pragma solidity ^0.8.11;

import "./Ownable.sol";
import "./Pausable.sol";
import "./CallerControl.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

contract CommonBase is Ownable, Pausable, CallerControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // The original address of this contract
    address private immutable _original;

    // @dev Emitted when native assets (token=address(0)) or tokens are withdrawn by owner.
    event Withdrawn(address indexed token, address indexed to, uint amount);

    constructor() {
        _original = address(this);
    }

    // @dev prevents delegatecall into the modified method
    modifier noDelegateCall() {
        _checkNotDelegateCall();
        _;
    }

    // @dev check whether deadline is reached
    modifier checkDeadline(uint256 deadline) {
        require(deadline == 0 || block.timestamp <= deadline, "CommonBase: transaction too old");
        _;
    }

    // @dev fallback function to receive native assets
    receive() external payable {}

    // @dev pause stops contract from doing any swap
    function pause() external onlyOwner {
        _pause();
    }

    // @dev resumes contract to do swap
    function unpause() external onlyOwner {
        _unpause();
    }

    // @dev withdraw eth to recipient
    function withdrawNativeAsset(uint amount, address recipient) external onlyOwner {
        payable(recipient).transfer(amount);
        emit Withdrawn(address(0), recipient, amount);
    }

    // @dev withdraw token to owner account
    function withdrawToken(address token, uint amount, address recipient) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
        emit Withdrawn(token, recipient, amount);
    }

    // @dev update caller allowed status
    function updateAllowedCaller(address caller, bool allowed) external onlyOwner {
        _updateAllowedCaller(caller, allowed);
    }

    // @dev ensure not a delegatecall
    function _checkNotDelegateCall() private view {
        require(address(this) == _original, "CommonBase: delegate call not allowed");
    }
}