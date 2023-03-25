// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapOldQlc is Ownable {
    mapping (string => bool) swaps;

    event Swap(uint256 _amount, address indexed _to, string _swapId);
    
    function swap(address newTokenAddr, uint256 _amount, address _to, string memory _swapId) external onlyOwner {
        require(!existsSwap(_swapId), "Duplicated swap");
        swaps[_swapId] = true;

        IERC20 tokenContract = IERC20(newTokenAddr);

        tokenContract.approve(address(this), _amount);
        tokenContract.transferFrom(address(this), _to, _amount);

        emit Swap(_amount, _to, _swapId);
    }

    function existsSwap(string memory _swapId) public view returns (bool) {
        return swaps[_swapId] == true;
    }
}