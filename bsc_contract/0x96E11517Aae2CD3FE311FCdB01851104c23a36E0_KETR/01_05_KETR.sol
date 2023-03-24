// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KETR is ERC20 {
    address private constant BURN_ADDR = 0x000000000000000000000000000000000000dEaD;
    mapping (address => bool) internal operator;
    bool public tradingEnabled = false;

    modifier onlyOperator {
        require(isOperator(msg.sender), "Only operator can perform this action");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20 (_name, _symbol) {
        operator[msg.sender] = true;
        operator[BURN_ADDR] = true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {

        if(!tradingEnabled) {
            require(isOperator(sender) || isOperator(recipient), "Trading not started");
        }

        super._transfer(sender, recipient, amount);
    }

    function mint(address _to, uint256 _amount) external onlyOperator {
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    function enableTrading(bool _enabled) external onlyOperator {
        tradingEnabled = _enabled;

        emit EnableTrading(_enabled);
    }

    function rescueToken(address _token, address _to, uint256 _amount) external onlyOperator {
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        require(_amount <= _contractBalance, "Insufficient token");

        IERC20(_token).transfer(_to, _amount);

        emit RescueToken(_token, _to, _amount);
    }

    function setOperator(address _userAddress, bool _bool) external onlyOperator {
        require(_userAddress != address(0), "Address zero");
        operator[_userAddress] = _bool;

        emit SetOperator(_userAddress, _bool);
    }

    function isOperator(address _userAddress) public view returns(bool) {
        return operator[_userAddress];
    }

    event Mint(address _to, uint256 _amount);
    event EnableTrading(bool _enabled);
    event RescueToken(address token, address to, uint256 amount);
    event SetOperator(address _userAddress, bool _bool);
}