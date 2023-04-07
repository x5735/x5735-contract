// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

/*
  ______                     ______                                 
 /      \                   /      \                                
|  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\ ______   ______ |  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\__   __   __  ______   ______  
| ¨ˆ¨ˆ__| ¨ˆ¨ˆ/      \ /      \| ¨ˆ¨ˆ___\¨ˆ¨ˆ  \ |  \ |  \|      \ /      \ 
| ¨ˆ¨ˆ    ¨ˆ¨ˆ  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\\¨ˆ¨ˆ    \| ¨ˆ¨ˆ | ¨ˆ¨ˆ | ¨ˆ¨ˆ \¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\
| ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ ¨ˆ¨ˆ  | ¨ˆ¨ˆ ¨ˆ¨ˆ    ¨ˆ¨ˆ_\¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\ ¨ˆ¨ˆ | ¨ˆ¨ˆ | ¨ˆ¨ˆ/      ¨ˆ¨ˆ ¨ˆ¨ˆ  | ¨ˆ¨ˆ
| ¨ˆ¨ˆ  | ¨ˆ¨ˆ ¨ˆ¨ˆ__/ ¨ˆ¨ˆ ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ  \__| ¨ˆ¨ˆ ¨ˆ¨ˆ_/ ¨ˆ¨ˆ_/ ¨ˆ¨ˆ  ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ ¨ˆ¨ˆ__/ ¨ˆ¨ˆ
| ¨ˆ¨ˆ  | ¨ˆ¨ˆ ¨ˆ¨ˆ    ¨ˆ¨ˆ\¨ˆ¨ˆ     \\¨ˆ¨ˆ    ¨ˆ¨ˆ\¨ˆ¨ˆ   ¨ˆ¨ˆ   ¨ˆ¨ˆ\¨ˆ¨ˆ    ¨ˆ¨ˆ ¨ˆ¨ˆ    ¨ˆ¨ˆ
 \¨ˆ¨ˆ   \¨ˆ¨ˆ ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ  \¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ \¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ  \¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ\¨ˆ¨ˆ¨ˆ¨ˆ  \¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ¨ˆ 
         | ¨ˆ¨ˆ                                             | ¨ˆ¨ˆ      
         | ¨ˆ¨ˆ                                             | ¨ˆ¨ˆ      
          \¨ˆ¨ˆ                                              \¨ˆ¨ˆ         
 * App:             https://ApeSwap.finance
 * Medium:          https://ape-swap.medium.com
 * Twitter:         https://twitter.com/ape_swap
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * Reddit:          https://reddit.com/r/ApeSwap
 * Instagram:       https://instagram.com/ApeSwap.finance
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarderV2 {
    /// @dev even if not all parameters are currently used in this implementation they help future proofing it
    function onReward(
        uint256 _pid,
        address _user,
        address _to,
        uint256 _pending,
        uint256 _stakedAmount,
        uint256 _lpSupply
    ) external;

    /// @dev passing stakedAmount here helps future proofing the interface
    function pendingTokens(
        uint256 pid,
        address user,
        uint256 amount
    ) external view returns (IERC20[] memory, uint256[] memory);
}