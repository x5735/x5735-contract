// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DBN is ERC20, Ownable {
    address private _manager;
    uint256 public totalSupplyLimit = 1000000000 * 10**18;

    bool public isTransferable = false;
    bool public isfreezedWhiteListTransfer = false;

    address[] public whitelistAddresses;

    mapping(address => uint256) private _whitelistedIndexes;
    mapping(address => bool) public isWhitelisted;

    constructor() ERC20("Dashbone Token", "DBN") {}

    function mint(address to, uint256 amount) public returns (bool) {
        require(
            msg.sender == owner() || msg.sender == _manager,
            "Owner can call this method"
        );
        require(
            totalSupply() + amount < totalSupplyLimit,
            "Total Supply exceeded"
        );
        _mint(to, amount);
        return true;
    }

    function burn(address account, uint256 amount) public returns (bool) {
        require(
            msg.sender == owner() || msg.sender == _manager,
            "Owner can call this method"
        );
        _burn(account, amount);
        return true;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(isTransferable, "Token are not Transferable yet.");
        if (isfreezedWhiteListTransfer)
            require(
                !isWhitelisted[msg.sender],
                "Whitelist Transfer is freezed."
            );
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(isTransferable, "Token are not Transferable yet.");
        return super.transferFrom(from, to, amount);
    }

    function pauseTransfer() public onlyOwner {
        isTransferable = false;
    }

    function resumeTransfer() public onlyOwner {
        isTransferable = true;
    }
    function updateIsFreezedWhiteListTransfer(bool _isfreezedWhiteListTransfer) public onlyOwner {
        require(isfreezedWhiteListTransfer != _isfreezedWhiteListTransfer, "Nothing to update.");
        isfreezedWhiteListTransfer = _isfreezedWhiteListTransfer;
    }

    function updateManager(address newManager) public onlyOwner {
        _manager = newManager;
    }

    function updateWhiteList(address account, bool add)
        public
        returns (address[] memory)
    {
        if (add) {
            if (isWhitelisted[account]) return whitelistAddresses;
            whitelistAddresses.push(account);
            _whitelistedIndexes[account] = whitelistAddresses.length - 1;
            isWhitelisted[account] = true;
            return whitelistAddresses;
        } else {
            uint256 index = _whitelistedIndexes[account];
            if (index >= whitelistAddresses.length) return whitelistAddresses;

            // address[] memory result ;
            address[] memory result = new address[](
                whitelistAddresses.length - 1
            );
            for (uint256 i = 0; i < whitelistAddresses.length; i++) {
                if (i < whitelistAddresses.length - 1) {
                    if (i < index) {
                        result[i] = whitelistAddresses[i];
                    } else {
                        result[i] = whitelistAddresses[i + 1];
                    }
                }
            }
            delete _whitelistedIndexes[account];
            whitelistAddresses = result;
            isWhitelisted[account] = false;
            return whitelistAddresses;
        }
    }

    function updateWhitelistAddresses(address[] memory accounts, bool _add)
        public
        onlyOwner
    {
        for (uint256 index = 0; index < accounts.length; index++) {
            updateWhiteList(accounts[index], _add);
        }
    }

    function getWhiteListedAddresses() public view returns (address[] memory) {
        return whitelistAddresses;
    }

    function getWhiteListedAddressesCount() public view returns (uint256) {
        return whitelistAddresses.length;
    }

    function getManager() public view returns (address) {
        return _manager;
    }
}