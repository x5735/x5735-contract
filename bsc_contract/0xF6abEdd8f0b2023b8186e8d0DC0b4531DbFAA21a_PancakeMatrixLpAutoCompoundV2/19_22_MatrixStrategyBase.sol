// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '../interfaces/IMatrixStrategy.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';

/// @title Base Strategy Framework, all strategies will inherit this
abstract contract MatrixStrategyBase is Ownable, Pausable {
    using SafeERC20 for IERC20;

    // Matrix contracts
    address public immutable vault;
    address public treasury;
    address public partner;

    // Tokens used
    address public wrapped = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public immutable want;

    uint256 public callFee = 1000;
    uint256 public partnerFee = 0;
    uint256 public treasuryFee = 9000;
    uint256 public securityFee = 10;
    uint256 public totalFee = 450;

    /***
     * {MAX_FEE} - Maximum fee allowed by the strategy. Hard-capped at 5%.
     * {PERCENT_DIVISOR} - Constant used to safely calculate the correct percentages.
     */

    uint256 public constant MAX_FEE = 500;
    uint256 public constant PERCENT_DIVISOR = 10000;

    /**
     * {Harvested} Event that is fired each time someone harvests the strat.
     * {TotalFeeUpdated} Event that is fired each time the total fee is updated.
     * {CallFeeUpdated} Event that is fired each time the call fee is updated.
     * {TreasuryUpdated} Event that is fired each time treasury address is updated.
     */
    event Harvested(address indexed harvester, uint256 _wantHarvested, uint256 _totalValueBefore, uint256 _totalValueAfter);
    event TotalFeeUpdated(uint256 newFee);
    event CallFeeUpdated(uint256 newCallFee, uint256 newTreasuryFee);
    event SecurityFeeUpdated(uint256 newSecurityFee);
    event PartnerFeeUpdated(uint256 newPartnerFee, uint256 newTreasuryFee);

    event TreasuryUpdated(address indexed _oldTreasury, address indexed _newTreasury);

    modifier onlyVault() {
        require(msg.sender == vault, '!vault');
        _;
    }

    constructor(
        address _want,
        address _vault,
        address _treasury
    ) {
        require(_vault != address(0), 'vault-is-zero');
        require(_treasury != address(0), 'treasury-is-zero');
        require(_want != address(0), 'want-is-zero');

        vault = _vault;
        treasury = _treasury;
        want = _want;
    }

    /**
     * @dev updates the total fee, capped at 5%
     */
    function updateTotalFee(uint256 _totalFee) external onlyOwner returns (bool) {
        require(_totalFee <= MAX_FEE, 'fee-too-high');
        totalFee = _totalFee;
        emit TotalFeeUpdated(totalFee);
        return true;
    }

    /**
     * @dev updates security fee, capped at 5%
     */
    function updateSecurityFee(uint256 _securityFee) external onlyOwner returns (bool) {
        require(_securityFee <= MAX_FEE, 'fee-too-high');
        securityFee = _securityFee;
        emit SecurityFeeUpdated(securityFee);
        return true;
    }

    /**
     * @dev updates the call fee and adjusts the treasury fee to cover the difference
     */
    function updateCallFee(uint256 _callFee) external onlyOwner returns (bool) {
        callFee = _callFee;
        treasuryFee = PERCENT_DIVISOR - callFee - partnerFee;
        emit CallFeeUpdated(callFee, treasuryFee);
        return true;
    }

    /**
     * @dev updates the partner fee and adjusts the treasury fee to cover the difference
     */
    function updatePartnerFee(uint256 _partnerFee) external onlyOwner returns (bool) {
        require(partner != address(0), 'partner-not-set');

        partnerFee = _partnerFee;
        treasuryFee = PERCENT_DIVISOR - partnerFee - callFee;
        emit PartnerFeeUpdated(partnerFee, treasuryFee);
        return true;
    }

    function updateTreasury(address _newTreasury) external onlyOwner returns (bool) {
        require(_newTreasury != address(0), 'treasury-is-zero');
        treasury = _newTreasury;
        return true;
    }

    function updatePartner(address _newPartner) external onlyOwner returns (bool) {
        require(_newPartner != address(0), 'partner-is-zero');
        partner = _newPartner;
        return true;
    }

    /**
     * @dev Puts funds in strategy at work
     * @notice Only vault can call this when not paused
     */
    function deposit() external virtual whenNotPaused onlyVault {
        _deposit();
    }

    function withdraw(uint256 _amount) external virtual onlyVault {
        uint256 _balanceHere = IERC20(want).balanceOf(address(this));

        if (_balanceHere < _amount) {
            _beforeWithdraw(_amount - _balanceHere);
            _balanceHere = IERC20(want).balanceOf(address(this));
        }

        if (_balanceHere > _amount) {
            _balanceHere = _amount;
        }
        uint256 _withdrawFee = (_balanceHere * securityFee) / PERCENT_DIVISOR;
        IERC20(want).safeTransfer(vault, _balanceHere - _withdrawFee);
    }

    function pause() external virtual onlyOwner {
        _pause();
        _removeAllowances();
    }

    function unpause() external virtual onlyOwner {
        _unpause();
        _giveAllowances();
        _deposit();
    }

    function beforeDeposit() external virtual onlyVault {}

    function retireStrat() external onlyVault {
        _beforeRetireStrat();
        uint256 _wantBalance = IERC20(want).balanceOf(address(this));
        IERC20(want).safeTransfer(vault, _wantBalance);
    }

    /// @notice pauses deposits and withdraws all funds from third party systems.
    function panic() external onlyOwner {
        _pause();
        _beforePanic();
    }

    /// @notice compounds earnings and charges performance fee
    function harvest() external whenNotPaused {
        require(!Address.isContract(msg.sender), '!contract');

        uint256 _totalValueBefore = totalValue();
        (uint256 _wantHarvested, uint256 _wrappedFeesAccrued) = _harvest();

        _chargeFees(_wrappedFeesAccrued);

        uint256 _totalValueAfter = totalValue();
        _deposit();

        emit Harvested(msg.sender, _wantHarvested, _totalValueBefore, _totalValueAfter);
    }

    /// @notice "want" Funds held in strategy + funds deployed elsewhere
    function totalValue() public view virtual returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    /// @notice For vault interface retro-compatibility
    function balanceOf() public view virtual returns (uint256) {
        return totalValue();
    }

    function _chargeFees(uint256 _wrappedFeesAccrued) internal virtual {
        uint256 _callFeeToUser = (_wrappedFeesAccrued * callFee) / PERCENT_DIVISOR;
        uint256 _feeToPartner = (_wrappedFeesAccrued * partnerFee) / PERCENT_DIVISOR;

        IERC20(wrapped).safeTransfer(msg.sender, _callFeeToUser);
        IERC20(wrapped).safeTransfer(treasury, _wrappedFeesAccrued - _callFeeToUser - _feeToPartner);

        if (partner != address(0)) {
            IERC20(wrapped).safeTransfer(partner, _feeToPartner);
        }
    }

    /// @notice Hooks to customize strategies behavior
    function _deposit() internal virtual {}

    function _beforeWithdraw(uint256 _amount) internal virtual {}

    function _harvest() internal virtual returns (uint256 _wantHarvested, uint256 _wrappedFeesAccrued) {}

    function _giveAllowances() internal virtual {}

    function _removeAllowances() internal virtual {}

    function _beforeRetireStrat() internal virtual {}

    function _beforePanic() internal virtual {}
}