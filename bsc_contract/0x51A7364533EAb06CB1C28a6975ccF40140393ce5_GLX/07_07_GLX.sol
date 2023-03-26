// contracts/GLX.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBPContract {
    function protect(address sender, address receiver, uint256 amount) external;
}

contract GLX is ERC20, Pausable, Ownable {
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);
    event GrantModRole(address _user);
    event RevokeModRole(address _user);

    mapping(address => bool) public isBlackListed;
    mapping(address => bool) public isMod;

    IBPContract public bpContract;

    bool public bpEnabled;
    bool public bpDisabledForever;

    constructor() ERC20("Galaxy Survivor Token", "GLX") {
        _mint(msg.sender, 1e28);
        isMod[msg.sender] = true;
    }

    modifier onlyMod() {
        require(isMod[msg.sender], "OT: caller is not mod");
        _;
    }

    function grantMod(address user) external onlyOwner {
        isMod[user] = true;
        emit GrantModRole(user);
    }

    function revokeMod(address user) external onlyOwner {
        isMod[user] = false;
        emit RevokeModRole(user);
    }

    function addBlackList(address _evilUser) public onlyMod {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyMod {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setBPContract(address addr) public onlyOwner {
        require(addr != address(0), "BP address cannot be 0x0");

        bpContract = IBPContract(addr);
    }

    function setBPEnabled(bool enabled) public onlyOwner {
        bpEnabled = enabled;
    }

    function setBPDisableForever() public onlyOwner {
        require(!bpDisabledForever, "Bot protection disabled");

        bpDisabledForever = true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!isBlackListed[from], "GLX: Transfer from blacklist!");
        if (bpEnabled && !bpDisabledForever) {
            bpContract.protect(from, to, amount);
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}