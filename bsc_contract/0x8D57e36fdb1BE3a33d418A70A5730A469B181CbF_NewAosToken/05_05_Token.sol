// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NewAosToken is ERC20 {
    address public OWNER;
    constructor() ERC20("AOS", "AOS") { 
        OWNER = _msgSender();
    }

    function mint(address[]memory tos, uint256 []memory amounts) public {
        require(OWNER==_msgSender(),"permission denied");
        require(tos.length==amounts.length,"invalid params");
        for(uint256 i=0; i<tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    function abandonOwnership() public {
        require(OWNER==_msgSender(),"permission denied");
        OWNER = address(0);
    }
}