// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./EconBaseContract.sol";

contract Econ20Signature is EconBaseContract {
    using ECDSA for bytes32;

    mapping(bytes32 => bool) private _handled; // withdrawId

    address public treasury;

    bytes32 public constant WITHDRAW_TREASURY = keccak256("WITHDRAW_TREASURY");

    event Deposited(address user, address token, uint256 amount);
    event Withdrawn(bytes32 withdrawId, address user, address token, uint256 amount);
    event WithdrawFailed(bytes32 withdrawId, address user, address token, uint256 amount);

    function initialize() public virtual initializer {
        __BaseContract_init();
    }

    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

    function withdrawTreasury(address _payment, uint256 _amount) external nonReentrant onlyRole(WITHDRAW_TREASURY) {
        require(_whitelistContract[_payment] && _amount > 0);

        withdraw(payable(treasury), _payment, _amount);
    }

    function deposit(address _token, uint256 _amount) external payable nonReentrant whenNotPaused whenNotMaintain {
        require(_whitelistContract[_token], "Error: TokenNotAccept");

        if (_token == address(0)) require(_amount == msg.value);
        else {
            require(IERC20(_token).allowance(_msgSender(), address(this)) >= _amount, "Error: InsufficientAllowance");
            require(IERC20(_token).transferFrom(_msgSender(), address(this), _amount), "Error: TransferFailed");
        }

        emit Deposited(_msgSender(), _token, _amount);
    }

    function getSignedMessageHash(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _expiryTime,
        bytes32 _withdrawId
    ) public view returns (bytes32) {
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), _token, _to, _amount, _expiryTime));
        bytes32 signedMessageHash = keccak256(abi.encodePacked(messageHash, _withdrawId));

        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", signedMessageHash));
    }

    function withdraw(
        address _token,
        uint256 _amount,
        uint256 _expiryTime,
        bytes32 _withdrawId,
        bytes memory signature
    ) external nonReentrant whenNotPaused whenNotMaintain {
        require(!_handled[_withdrawId]);

        bytes32 ethSignedMessageHash = getSignedMessageHash(_token, _msgSender(), _amount, _expiryTime, _withdrawId);
        (address recovered, ) = ethSignedMessageHash.tryRecover(signature);

        require(recovered == signer, "Error: InvalidSignature");
        require(block.timestamp <= _expiryTime, "Error: ExpiriedTime");

        _handled[_withdrawId] = true;

        if (_token == address(0)) {
            (bool success, ) = payable(_msgSender()).call{ value: _amount }("");

            if (success) emit Withdrawn(_withdrawId, _msgSender(), _token, _amount);
            else emit WithdrawFailed(_withdrawId, _msgSender(), _token, _amount);
        } else {
            try IERC20(_token).transfer(_msgSender(), _amount) returns (bool) {
                emit Withdrawn(_withdrawId, _msgSender(), _token, _amount);
            } catch {
                emit WithdrawFailed(_withdrawId, _msgSender(), _token, _amount);
            }
        }
    }

    function cancelWithdraw(
        address _wallet,
        address _token,
        uint256 _amount,
        uint256 _expiryTime,
        bytes32 _withdrawId,
        bytes memory signature
    ) external {
        require(_msgSender() == _wallet || hasRole(CONFIG_ROLE, _msgSender()), "Error: NotPermission");

        require(!_handled[_withdrawId]);

        bytes32 ethSignedMessageHash = getSignedMessageHash(_token, _wallet, _amount, _expiryTime, _withdrawId);
        (address recovered, ) = ethSignedMessageHash.tryRecover(signature);

        require(recovered == signer, "Error: InvalidSignature");
        _handled[_withdrawId] = true;

        emit WithdrawFailed(_withdrawId, _wallet, _token, _amount);
    }
}