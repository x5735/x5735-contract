// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

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
 * Discord:         https://discord.com/ApeSwap
 * Reddit:          https://reddit.com/r/ApeSwap
 * Instagram:       https://instagram.com/ApeSwap.finance
 * GitHub:          https://github.com/ApeSwapFinance
 */

interface IContractWhitelist {
    function getWhitelistLength() external returns (uint256);

    function getWhitelistAtIndex(uint256 _index) external returns (address);

    function isWhitelisted(address _address) external returns (bool);

    function setWhitelistEnabled(bool _enabled) external;

    function setContractWhitelist(address _address, bool _enabled) external;

    function setBatchContractWhitelist(address[] memory _addresses, bool[] memory _enabled) external;
}