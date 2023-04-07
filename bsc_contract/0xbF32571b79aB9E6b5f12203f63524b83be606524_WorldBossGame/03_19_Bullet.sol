// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./BulletPauseable.sol";
import "./Constant.sol";

abstract contract Bullet is
    ReentrancyGuardUpgradeable,
    BulletPauseable
{
    struct WithdrawForm {
        uint256 amount;
        uint256 time;
    }
    event Topup(address user, uint256 amount);
    event PreWithdraw(address user, uint256 amount, uint256 timestamp);
    event Withdraw(address user, uint256 amount, uint256 timestamp);
    event ChargeFee(address user, uint256 amount);
    event WithdrawCDUpdated(uint256 cd);
    event FeeUpdated(uint256 fee);
    event TopupToSystem(address user, uint256 amount);
    event WithdrawFromSystem(address user, uint256 amount);

    mapping(address => uint256) private _bullet_balance;
    mapping(address => uint256) private _topup_block;
    mapping(address => WithdrawForm) public withdraw_form;
    address public token;
    uint256 public fee;
    uint256 private _system_bullet;
    address public system_wallet;
    address public fee_wallet;
    uint256 private _frozen_bullet;
    uint256 public withdraw_cd;

    function _initBullet(
        address token_,
        address system_wallet_,
        address fee_wallet_,
        uint256 fee_
    ) internal {
        token = token_;
        _setWallet(system_wallet_, fee_wallet_);
        require(fee_ <= Constant.E3);
        fee = fee_;
        withdraw_cd = 86400;
    }

    function _setWallet(address system_wallet_, address fee_wallet_) internal {
        require(system_wallet_ != address(0), "invalid system_wallet_");
        system_wallet = system_wallet_;
        require(fee_wallet_ != address(0), "invalid system_wallet_");
        fee_wallet = fee_wallet_;
    }

    function setWallet(address system_wallet_, address fee_wallet_) external onlyOwner {
        _setWallet(system_wallet_, fee_wallet_);
    }

    function topup(uint256 amount) external payable nonReentrant {
        if (token == address(0)) {
            require(amount == msg.value, "invalid msg.value");
        } else {
            require(0 == msg.value, "invalid msg.value");
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        }
        _topup(msg.sender, amount);
    }

    function batchTopup(
        address[] calldata users,
        uint256[] calldata amounts
    ) external payable nonReentrant onlyAdmin {
        uint256 _total;
        require(users.length == amounts.length);

        for (uint i = 0; i < users.length; i++) {
            _topup(users[i], amounts[i]);
            _total += amounts[i];
        }

        if (token == address(0)) {
            require(_total == msg.value, "invalid msg.value");
        } else {
            require(0 == msg.value, "invalid msg.value");
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), _total);
        }
    }

    function _topup(address to, uint256 amount) internal {
        require(to.code.length == 0, "topup to EOA only");
        _topup_block[to] = block.number;
        _addBullet(to, amount);
        emit Topup(to, amount);
    }

    function _beforeWithdraw() internal virtual {}

    function preWithdraw(uint256 amount) external whenBulletNotPaused {
        require(withdraw_form[msg.sender].amount == 0, "withdraw pls");
        _beforeWithdraw();
        _reduceBullet(msg.sender, amount);
        withdraw_form[msg.sender].amount = amount;
        withdraw_form[msg.sender].time = block.timestamp;
        emit PreWithdraw(msg.sender, amount, block.timestamp);
    }

    function withdrawTimeOf(address user) public view returns (uint256) {
        if (isBulletPausing) return type(uint256).max;
        return withdraw_form[user].time + withdraw_cd;
    }

    function withdraw() external nonReentrant whenBulletNotPaused {
        require(withdraw_form[msg.sender].amount > 0, "preWithdraw need");
        require(withdrawTimeOf(msg.sender) <= block.timestamp);
        uint256 amount = withdraw_form[msg.sender].amount;

        uint256 _fee = (amount * fee) / Constant.E4;
        uint256 _amount = amount - _fee;
        if (token == address(0)) {
            Address.sendValue(payable(msg.sender), _amount);
            Address.sendValue(payable(fee_wallet), _fee);
        } else {
            SafeERC20.safeTransfer(IERC20(token), msg.sender, _amount);
            SafeERC20.safeTransfer(IERC20(token), fee_wallet, _fee);
        }
        withdraw_form[msg.sender].amount = 0;
        withdraw_form[msg.sender].time = 0;
        emit Withdraw(msg.sender, amount, block.timestamp);
        emit ChargeFee(msg.sender, _fee);
    }

    function setFee(uint256 fee_) external onlyOwner {
        require(fee_ <= Constant.E3);
        fee = fee_;
        emit FeeUpdated(fee);
    }

    function setWithdrawCD(uint256 cd_) external onlyOwner {
        withdraw_cd = cd_;
        emit WithdrawCDUpdated(withdraw_cd);
    }

    function _addBullet(address user, uint256 amount) internal {
        _bullet_balance[user] += amount;
    }

    function _reduceBullet(address user, uint256 amount) internal {
        require(_topup_block[user] < block.number, "Error: same block");
        require(_bullet_balance[user] >= amount, "insufficient bullet_amount");
        _bullet_balance[user] -= amount;
    }

    function bulletOf(address user) public view returns (uint256) {
        return _bullet_balance[user];
    }

    function topupToSystem(uint256 amount) external payable nonReentrant {
        if (token == address(0)) {
            require(amount == msg.value, "invalid amount");
        } else {
            require(0 == msg.value, "Error");
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        }
        _addSystemBullet(amount);
        emit TopupToSystem(msg.sender, amount);
    }

    function withdrawFromSystem(uint256 amount) external nonReentrant onlyAdmin {
        require(amount + _frozen_bullet <= _system_bullet, "insufficient system_bullet");
        _reduceSystemBullet(amount);
        if (token == address(0)) {
            Address.sendValue(payable(system_wallet), amount);
        } else {
            SafeERC20.safeTransfer(IERC20(token), system_wallet, amount);
        }
        emit WithdrawFromSystem(msg.sender, amount);
    }

    function _addSystemBullet(uint256 amount) internal {
        _system_bullet += amount;
    }

    function _reduceSystemBullet(uint256 amount) internal {
        require(_system_bullet >= amount);
        _system_bullet -= amount;
    }

    function systemBullet() public view onlyAdmin returns (uint256) {
        return _system_bullet;
    }

    function _addFrozenBullet(uint256 amount) internal {
        _frozen_bullet += amount;
    }

    function _reduceFrozenBullet(uint256 amount) internal {
        require(_frozen_bullet >= amount);
        _frozen_bullet -= amount;
    }

    function frozenBullet() public view returns (uint256) {
        return _frozen_bullet;
    }
}