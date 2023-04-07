// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract EconBaseContract is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    address public signer;
    bool private _paused;

    uint256 public startTimeMaintain;
    uint256 public endTimeMaintain;

    mapping(address => bool) internal _whitelistContract;

    event SetPaused(bool paused);
    event SetSigner(address signer);
    event SetMaintainTime(uint256 startTimeMaintain, uint256 endTimeMaintain);
    event WhitelistContractAddress(address contractAddress, bool allowance);
    event Withdraw(address to, address token, uint256 amount);

    modifier whenNotPaused() {
        require(!_paused, "Error: Paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Error: NotPaused");
        _;
    }

    modifier whenNotMaintain() {
        require(block.timestamp < startTimeMaintain || endTimeMaintain <= block.timestamp, "Error: MaintainTime");
        _;
    }

    function __BaseContract_init() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CONFIG_ROLE, _msgSender());

        _paused = false;
    }

    function getConfig()
        public
        view
        returns (
            address,
            bool,
            uint256,
            uint256
        )
    {
        return (signer, _paused, startTimeMaintain, endTimeMaintain);
    }

    function setWhitelistContractAddress(address _contractAddress, bool _allowance) public onlyRole(CONFIG_ROLE) {
        require(_whitelistContract[_contractAddress] != _allowance);

        if (_allowance) _whitelistContract[_contractAddress] = _allowance;
        else delete _whitelistContract[_contractAddress];

        emit WhitelistContractAddress(_contractAddress, _allowance);
    }

    function setSigner(address _signer) public onlyRole(CONFIG_ROLE) {
        signer = _signer;
        emit SetSigner(signer);
    }

    function setPaused(bool _pause) public onlyRole(CONFIG_ROLE) {
        require(_paused != _pause);

        _paused = _pause;
        emit SetPaused(_paused);
    }

    function setTimeMaintain(uint256 _startTimeMaintain, uint256 _endTimeMaintain) public onlyRole(CONFIG_ROLE) {
        require(_startTimeMaintain <= _endTimeMaintain, "Error: InvalidTime");

        startTimeMaintain = _startTimeMaintain;
        endTimeMaintain = _endTimeMaintain;

        emit SetMaintainTime(startTimeMaintain, endTimeMaintain);
    }

    function withdraw(
        address payable _to,
        address _token,
        uint256 _amount
    ) public nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "Error: ExceedsBalance");
            require(_to.send(_amount), "Error: TransferFailed");
        } else {
            require(IERC20(_token).balanceOf(address(this)) >= _amount, "Error: ExceedsBalance");
            require(IERC20(_token).transfer(_to, _amount), "Error: TransferFailed");
        }

        emit Withdraw(_to, _token, _amount);
    }

    function withdrawERC721(
        address _to,
        address _contractAddress,
        uint256 _tokenId
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(_contractAddress).safeTransferFrom(address(this), _to, _tokenId);
    }
}