// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TransferFirewall is Ownable {
    bool private firewallInited;
    bool private firewallActive;

    uint256 public firewallOpened;
    mapping(address => bool) internal _isWhitelisted;

    event FirewallOpenChanged(uint256 timestamp);
    event FirewallActivated(bool active);
    event FirewallWhitelisted(address indexed account, bool isWhitelisted);

    function initFirewall(uint256 _start) public virtual onlyOwner {
        require(!firewallInited, "Firewall: Already initialized");
        firewallInited = true;
        whitelistAccount(owner(), true);
        whitelistAccount(address(0), true);
        setFirewallOpen(_start);
        setFirewallActive(true);
    }

    function setFirewallOpen(uint256 _time) public virtual onlyOwner {
        require(firewallOpened == 0 || firewallOpened > block.timestamp, "Firewall: Too late");
        firewallOpened = _time;
        emit FirewallOpenChanged(firewallOpened);
    }

    function setFirewallActive(bool _active) public virtual onlyOwner {
        firewallActive = _active;
        emit FirewallActivated(firewallActive);
    }

    function whitelistAccount(address _account, bool _whitelisted) public virtual onlyOwner {
        _isWhitelisted[_account] = _whitelisted;
        emit FirewallWhitelisted(_account, _whitelisted);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _isWhitelisted[account];
    }

    modifier onlyWhitelisted(address sender, address target) {
        require(!firewallActive || _isWhitelisted[target] || _isWhitelisted[sender],
            'Firewall: transfer between excluded addresses disallowed');
        require(firewallOpened > 0 && firewallOpened <= block.timestamp, 'Firewall: transfers not enabled yet');
        _;
    }
}