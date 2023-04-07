// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IERC20Pausable.sol";

contract KartBoxMigration is AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Pausable;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    IERC20Pausable public immutable kart;
    IERC20 public immutable kartb;
    address public recipient;
    uint256 public swappedAmount;

    EnumerableSet.AddressSet private _blacklist;

    event UpdateRecipient(address indexed updater, address recipient);
    event UpdateBlacklist(address indexed updater);
    event Swap(address indexed user, uint256 amount);

    constructor(address _kart, address _kartb, address _recipient) {
        require(_kart != address(0), "kart address is the zero address");
        require(_kartb != address(0), "kartb address is the zero address");
        require(
            _recipient != address(0),
            "recipient address is the zero address"
        );

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MAINTAINER_ROLE, _msgSender());

        kart = IERC20Pausable(_kart);
        kartb = IERC20(_kartb);
        _updateRecipient(_msgSender(), _recipient);
    }

    modifier pausedGuard() {
        require(kart.paused(), "kart must be paused");
        kart.unpause();
        _;
        kart.pause();
    }

    modifier notInBlacklist(address user) {
        require(!_blacklist.contains(user), "user is in blacklist");
        _;
    }

    function _updateRecipient(address _sender, address _recipient) private {
        recipient = _recipient;
        emit UpdateRecipient(_sender, _recipient);
    }

    function updateRecipient(address _recipient) external {
        require(
            hasRole(MAINTAINER_ROLE, _msgSender()),
            "must have maintainer role"
        );
        require(
            _recipient != address(0),
            "recipient address is the zero address"
        );
        _updateRecipient(_msgSender(), _recipient);
    }

    function addUserToBlacklist(address user) external {
        require(
            hasRole(MAINTAINER_ROLE, _msgSender()),
            "must have maintainer role"
        );

        require(_blacklist.add(user), "user is already in blacklist");
        emit UpdateBlacklist(_msgSender());
    }

    function addUsersToBlacklist(address[] calldata users) external {
        require(
            hasRole(MAINTAINER_ROLE, _msgSender()),
            "must have maintainer role"
        );

        for (uint256 i; i < users.length; i++) {
            _blacklist.add(users[i]);
        }
        emit UpdateBlacklist(_msgSender());
    }

    function removeUserOutBlacklist(address user) external {
        require(
            hasRole(MAINTAINER_ROLE, _msgSender()),
            "must have maintainer role"
        );

        require(_blacklist.remove(user), "user is not in blacklist");
    }

    function swap(
        uint256 amount
    ) external notInBlacklist(_msgSender()) pausedGuard {
        require(amount > 0, "amount must be greater than 0");
        swappedAmount += amount;
        kart.safeTransferFrom(_msgSender(), recipient, amount);
        kartb.safeTransfer(_msgSender(), amount);
        emit Swap(_msgSender(), amount);
    }

    function withdraw(address token, uint256 amount) external {
        require(
            hasRole(MAINTAINER_ROLE, _msgSender()),
            "must have maintainer role"
        );

        IERC20(token).safeTransfer(_msgSender(), amount);
    }

    function blacklist() external view returns (address[] memory) {
        return _blacklist.values();
    }

    function isInBlacklist(address user) external view returns (bool) {
        return _blacklist.contains(user);
    }

    function backListLength() external view returns (uint256) {
        return _blacklist.length();
    }

    function blacklistAt(uint256 index) external view returns (address) {
        return _blacklist.at(index);
    }
}