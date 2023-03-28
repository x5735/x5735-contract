// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IVeToken.sol";
import "../interfaces/IVeDist.sol";
import "../interfaces/IPairFactory.sol";
import "../interfaces/ISolidlyFactory.sol";
import "../interfaces/ICpveTHEConfigurator.sol";

contract CpveTHESolidStaker is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Addresses used
    IVoter immutable public solidVoter;
    IVeToken immutable public ve;
    IVeDist immutable public veDist;
    ICpveTHEConfigurator immutable configurator;
    IERC20 immutable public want;

    // Want token and our NFT Token ID
    uint256 public mainTokenId;
    uint256 public reserveTokenId;
    uint256 public redeemTokenId;

    // Max Lock time, Max variable used for reserve split and the reserve rate.
    uint16 public constant MAX = 10000;
    uint256 public constant MAX_RATE = 1e18;
    // Vote weight decays linearly over time. Lock time cannot be more than `MAX_LOCK` (2 years).
    uint256 public constant MAX_LOCK = 365 days * 2;

    address public keeper;
    address public voter;
    address public polWallet;
    address public daoWallet;

    // Our on chain events.
    event CreateLock(address indexed user, uint256 veTokenId, uint256 amount, uint256 unlockTime);
    event NewManager(address _keeper, address _voter, address _polWallet, address _daoWallet);
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event SetRedeemTokenId(uint256 oldValue, uint256 newValue);
    event SplitMainNFT(uint256 oldValue, uint256 newValue);
    event MergeNFT(uint256 from, uint256 to);

    // Checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(
            msg.sender == owner() || msg.sender == keeper,
            "CpveTHESolidStaker: MANAGER_ONLY"
        );
        _;
    }

    // Checks that caller is either owner or keeper.
    modifier onlyVoter() {
        require(msg.sender == voter, "CpveTHESolidStaker: VOTER_ONLY");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _keeper,
        address _voter,
        address _polWallet,
        address _daoWallet,
        address _configurator
    ) ERC20(_name, _symbol) {
        configurator = ICpveTHEConfigurator(_configurator);

        solidVoter = IVoter(configurator.solidVoter());
        ve = IVeToken(configurator.ve());
        want = IERC20(configurator.want());
        veDist = IVeDist(configurator.veDist());

        keeper = _keeper;
        voter = _voter;
        polWallet = _polWallet;
        daoWallet = _daoWallet;

        want.safeApprove(address(ve), type(uint256).max);
    }

    function deposit(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(mainTokenId > 0 && reserveTokenId > 0, "CpveTHE: NOT_ASSIGNED");
        uint256 currentPeg = getCurrentPeg();
        require(currentPeg >= configurator.maxPeg(), "CpveTHE: NOT_MINT_WITH_UNDER_PEG");
        lock();
        (uint256 _lockedAmount, ) = ve.locked(_tokenId);
        if (_lockedAmount > 0) {
            ve.transferFrom(msg.sender, address(this), _tokenId);
            if (balanceOfWantInReserveVe() > requiredReserve()) {
                ve.merge(_tokenId, mainTokenId);
            } else {
                ve.merge(_tokenId, reserveTokenId);
            }
            
            _mint(msg.sender, _lockedAmount);
            emit Deposit(_lockedAmount);
        }
    }

    function _split(uint256[] memory _amounts, uint256 _tokenId) internal returns (uint256 tokenId0, uint256 tokenId1) {
        uint256 totalNftBefore = ve.balanceOf(address(this));
        ve.split(_amounts, _tokenId);
        uint256 totalNftAfter = ve.balanceOf(address(this));
        require(totalNftAfter == totalNftBefore + 1, "CpveTHE: SPLIT_NFT_FAILED");
        
        tokenId1 = ve.tokenOfOwnerByIndex(address(this), totalNftAfter - 1);
        tokenId0 = ve.tokenOfOwnerByIndex(address(this), totalNftAfter - 2);
    }

    function lock() public { 
        if (configurator.isAutoIncreaseLock()) {
            uint256 unlockTime = (block.timestamp + MAX_LOCK) / 1 weeks * 1 weeks;
            (, uint256 mainEndTime) = ve.locked(mainTokenId);
            (, uint256 reserveEndTime) = ve.locked(reserveTokenId);
            if (unlockTime > mainEndTime) ve.increase_unlock_time(mainTokenId, MAX_LOCK);
            if (unlockTime > reserveEndTime) ve.increase_unlock_time(reserveTokenId, MAX_LOCK);
        }
    }

    function split(uint256 _amount) external nonReentrant onlyManager {
        require(mainTokenId > 0 && reserveTokenId > 0, "CpveTHE: NOT_ASSIGNED");
        uint256 totalMainAmount = balanceOfWantInMainVe();
        uint256 reserveAmount = balanceOfWantInReserveVe();
        require(_amount < totalMainAmount - MAX_RATE, "CpveTHE: INSUFFICIENCY_AMOUNT_OUT");
        if (_amount > 0) {
            uint256[] memory _amounts = new uint256[](2);
            _amounts[0] = _amount;
            _amounts[1] = totalMainAmount - _amount;
            (uint256 tokenIdToMergeReserve, uint256 newMainTokenId) = _split(_amounts, mainTokenId);
            emit SplitMainNFT(mainTokenId, newMainTokenId);
            if (redeemTokenId == mainTokenId) {
                redeemTokenId = newMainTokenId;
            }

            mainTokenId = newMainTokenId;
            ve.merge(tokenIdToMergeReserve, reserveTokenId);
            require(balanceOfWantInReserveVe() == reserveAmount + _amount, "CpveTHE: SPLIT_ERROR");
        }
    }

    function merge(uint256 from, uint256 to) external nonReentrant {
        require(to == mainTokenId || to == reserveTokenId, "CpveTHE: TO_INVALID");
        require(from != mainTokenId && from != reserveTokenId, "CpveTHE: FROM_INVALID");
        ve.merge(from, to);
        emit MergeNFT(from, to); 
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(redeemTokenId > 0, "CpveTHE: NOT_ASSIGNED");
        uint256 lastVoted = solidVoter.lastVoted(redeemTokenId);
        require(block.timestamp > lastVoted + configurator.minDuringTimeWithdraw(), "CpveTHE: PAUSED_AFTER_VOTE");

        uint256 withdrawableAmount = withdrawableBalance();
        require(withdrawableAmount > MAX_RATE && _amount < withdrawableAmount - MAX_RATE, "CpveTHE: INSUFFICIENCY_AMOUNT_OUT");
        _burn(msg.sender, _amount);
        uint256 redeemFeePercent = configurator.redeemFeePercent();
        if (redeemFeePercent > 0) {
            uint256 redeemFeeAmount = (_amount * redeemFeePercent) / MAX;
            if (redeemFeeAmount > 0) {
                _amount = _amount - redeemFeeAmount;
                // mint fee
                _mint(polWallet, redeemFeeAmount);
            }
        }

        if (ve.voted(redeemTokenId)) {
            solidVoter.reset(redeemTokenId);
        }
        uint256[] memory _amounts = new uint256[](2);
        _amounts[0] = _amount;
        _amounts[1] = withdrawableAmount - _amount;
        (uint256 tokenIdForUser, uint256 tokenIdRemaining) = _split(_amounts, redeemTokenId);
        if (mainTokenId == redeemTokenId) {
            mainTokenId = tokenIdRemaining;
        } else {
            reserveTokenId = tokenIdRemaining;
        }
        redeemTokenId = tokenIdRemaining;

        ve.transferFrom(address(this), msg.sender, tokenIdForUser);
        emit Withdraw(_amount);
    }

    function totalWant() public view returns (uint256) {
        return balanceOfWantInMainVe() + balanceOfWantInReserveVe();
    }

    function lockInfo(uint256 _tokenId)
        public
        view
        returns (
            uint256 endTime,
            uint256 secondsRemaining
        )
    {
        (, endTime) = ve.locked(_tokenId);
        secondsRemaining = endTime > block.timestamp
            ? endTime - block.timestamp
            : 0;
    }

    function requiredReserve() public view returns (uint256 reqReserve) {
        reqReserve = balanceOfWantInMainVe() * configurator.reserveRate() / MAX;
    }

    function withdrawableBalance() public view returns (uint256 wants) {
        (wants, ) = ve.locked(redeemTokenId);
    }

    function balanceOfWantInMainVe() public view returns (uint256 wants) {
        (wants, ) = ve.locked(mainTokenId);
    }

    function balanceOfWantInReserveVe() public view returns (uint256 wants) {
        (wants, ) = ve.locked(reserveTokenId);
    }

    function resetVote(uint256 _tokenId) external onlyVoter {
        solidVoter.reset(_tokenId);
    }

    function createReserveLock(
        uint256 _amount,
        uint256 _lock_duration
    ) external onlyManager {
        require(reserveTokenId == 0, "CpveTHE: ASSIGNED");
        require(_amount > 0, "CpveTHE: ZERO_AMOUNT");

        want.safeTransferFrom(address(msg.sender), address(this), _amount);
        reserveTokenId = ve.create_lock(_amount, _lock_duration);
        redeemTokenId = reserveTokenId;
        _mint(msg.sender, _amount);

        emit CreateLock(msg.sender, mainTokenId, _amount, _lock_duration);
    }

    function createMainLock(
        uint256 _amount,
        uint256 _lock_duration
    ) external onlyManager {
        require(mainTokenId == 0, "CpveTHE: ASSIGNED");
        require(_amount > 0, "CpveTHE: ZERO_AMOUNT");

        want.safeTransferFrom(address(msg.sender), address(this), _amount);
        mainTokenId = ve.create_lock(_amount, _lock_duration);
        _mint(msg.sender, _amount);

        emit CreateLock(msg.sender, mainTokenId, _amount, _lock_duration);
    }

    // Whitelist new token
    function whitelist(address _token, uint256 _tokenId) external onlyManager {
        solidVoter.whitelist(_token, _tokenId);
    }

    function setRedeemTokenId(uint256 _tokenId) external onlyManager {
        require(_tokenId == mainTokenId || _tokenId == reserveTokenId, "CpveTHE: NOT_ASSIGNED_TOKEN");
        emit SetRedeemTokenId(redeemTokenId, _tokenId);
        redeemTokenId = _tokenId;
    }

    // Pause deposits
    function pause() public onlyManager {
        _pause();
        want.safeApprove(address(ve), 0);
    }

    // Unpause deposits
    function unpause() external onlyManager {
        _unpause();
        want.safeApprove(address(ve), type(uint256).max);
    }

    function getCurrentPeg() public view returns (uint256) {
        address pairAddress = ISolidlyFactory(solidVoter.factory()).getPair(address(want), address(this), false);
        require(pairAddress != address(0), "CpveTHE: LP_INVALID");
        IPairFactory pair = IPairFactory(pairAddress);
        address token0 = pair.token0();
        (uint256 _reserve0, uint256 _reserve1, ) = pair.getReserves();
        if (token0 == address(this)) {
            return _reserve1 * MAX_RATE / _reserve0;
        } else {
            return _reserve0 * MAX_RATE / _reserve1;
        }
    }

    function setManager(
        address _keeper,
        address _voter,
        address _polWallet,
        address _daoWallet
    ) external onlyManager {
        keeper = _keeper;
        voter = _voter;
        polWallet = _polWallet;
        daoWallet = _daoWallet;
        emit NewManager(_keeper, _voter, _polWallet, _daoWallet);
    }
}