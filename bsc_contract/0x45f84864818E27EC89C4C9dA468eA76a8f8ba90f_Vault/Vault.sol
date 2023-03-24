/**
 *Submitted for verification at BscScan.com on 2023-03-23
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

IERC20 constant W3C = IERC20(0x55d398326f99059fF775485246999027B3197955);

address constant rec = 0x602BD41d8e920872fc79C732aA14FC653dcf10c2;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        emit OwnerUpdated(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function setOwner(address newOwner) public virtual onlyOwner {
        owner = newOwner;
        emit OwnerUpdated(msg.sender, newOwner);
    }
}

contract Vault is Owned {
    event Deposit(address indexed sender, uint256 amount);
    struct Receord {
        address depositer;
        uint256 amount;
    }
    Receord[] public historyReceords;
    mapping(address => uint256[]) indexs;
    constructor(address payable dev) payable {
        (bool success, ) = dev.call{value: msg.value}("");
        require(success, "Failed");
    }
    function deposit(uint256 amount) external {
        historyReceords.push(Receord({depositer: msg.sender, amount: amount}));
        uint256 counter = historyReceords.length - 1;
        indexs[msg.sender].push(counter);

        W3C.transferFrom(msg.sender, rec, amount);
        emit Deposit(msg.sender, amount);
    }

    function withdrawToken(IERC20 token, uint256 _amount) external onlyOwner {
        token.transfer(msg.sender, _amount);
    }
}