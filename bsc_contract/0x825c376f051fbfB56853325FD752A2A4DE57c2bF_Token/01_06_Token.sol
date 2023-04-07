// SPDX-License-Identifier: MIT
// GoldQuality

pragma solidity ^0.8.19;

import "ERC20.sol";
import "Ownable.sol";

contract Token is ERC20, Ownable {
    bool public isLaunch;
    address public burnAddress;
    mapping(address => bool) public whiteList;

    address public constant SALE_ADDRESS = 0xa5c98A0FC152d3A356336F56F216793482407702;
    address public constant STAKING_OPTION_ADDRESS = 0x4FB39F9D0b8e0469ACA8d63f1a43823fD9c2E511;
    address public constant BONUS_ADDRESS = 0x27d732517fbF2a6B09CFbC2561fd7B943F1771df;
    address public constant DEVELOPMENT_ADDRESS = 0x1a43e04166968b0e8A529280566a92ec25D6B89B;

    constructor() ERC20("Gold Quality Token", "GQT")
    {
        isLaunch = false;

        whiteList[address(this)] = true;
        whiteList[SALE_ADDRESS] = true;
        whiteList[STAKING_OPTION_ADDRESS] = true;
        whiteList[BONUS_ADDRESS] = true;
        whiteList[DEVELOPMENT_ADDRESS] = true;

        _mint(address(this), 99999999e18);

        _transfer(address(this), SALE_ADDRESS, 31400000e18);
        _transfer(address(this), STAKING_OPTION_ADDRESS, 54599999e18);
        _transfer(address(this), BONUS_ADDRESS, 8000000e18);
        _transfer(address(this), DEVELOPMENT_ADDRESS, 6000000e18);
    }

    function launch()
    external onlyOwner
    {
        require(!isLaunch, "Already launched");
        isLaunch = true;
    }

    function setBurnAddress(address _burnAddress)
    external onlyOwner
    {
        require(burnAddress == address(0), "Burn address already set");
        burnAddress = _burnAddress;
    }

    function changeWhiteList(address _address, bool _status)
    external onlyOwner
    {
        require(whiteList[_address] == !_status, "Address is already in this status");
        whiteList[_address] = _status;
    }

    function burn(uint256 amount)
    external
    {
        require(burnAddress == _msgSender(), "Caller has no rights to burn");
        _burn(_msgSender(), amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
    internal override
    {
        if (!isLaunch) {
            require(whiteList[from] || whiteList[to], "Transfers are not yet allowed");
        }
    }
}