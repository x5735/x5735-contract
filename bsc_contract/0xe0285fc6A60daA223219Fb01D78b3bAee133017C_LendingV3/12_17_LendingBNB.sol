// SPDX-License-Identifier: MIT
pragma solidity = 0.6.12;
pragma experimental ABIEncoderV2;

import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {VaultV2} from "./libraries/gsdlending/VaultV2.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";

import {CDPv2} from "./libraries/gsdlending/CDPv2.sol";
import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {IVaultAdapterV2} from "./interfaces/IVaultAdapterV2.sol";
import {PriceRouter} from "./libraries/gsdlending/PriceRouter.sol";
import {IGsdStaking} from "./interfaces/IGsdStaking.sol";

contract LendingV3 is ReentrancyGuard {

    using CDPv2 for CDPv2.Data;
    using VaultV2 for VaultV2.Data;
    using VaultV2 for VaultV2.List;
    using SafeERC20 for IMintableERC20;
    using SafeMath for uint256;
    using Address for address;
    using PriceRouter for PriceRouter.Router;
    using FixedPointMath for FixedPointMath.FixedDecimal;

    address public constant ZERO_ADDRESS = address(0);

    /// @dev Resolution for all fixed point numeric parameters which represent percents. The resolution allows for a
    /// granularity of 0.01% increments.
    uint256 public constant PERCENT_RESOLUTION = 10000;

    PriceRouter.Router public _router;

    /// @dev usdc token.
    IMintableERC20 public usdcToken;

    /// @dev aux token.
    IMintableERC20 public auxToken;

    /// @dev The address of the account which currently has administrative capabilities over this contract.
    address public governance;

    /// @dev The address of the pending governance.
    address public pendingGovernance;

    /// @dev The address of the account which can initiate an emergency withdraw of funds in a vault.
    address public sentinel;

    /// @dev The address of the staking contract to receive aux for GSD staking rewards.
    address public staking;

    /// @dev The percent of each profitable harvest that will go to the staking contract.
    uint256 public stakingFee;

    /// @dev The address of the contract which will receive fees.
    address public rewards;

    /// @dev The percent of each profitable harvest that will go to the rewards contract.
    uint256 public harvestFee;

    /// @dev The total amount the native token deposited into the system that is owned by external users.
    uint256 public totalDepositedUsdc;

    /// @dev A flag indicating if the contract has been initialized yet.
    bool public initialized;

    /// @dev A flag indicating if deposits and flushes should be halted and if all parties should be able to recall
    /// from the active vault.
    bool public emergencyExit;

    /// @dev when movemetns are bigger than this number flush is activated.
    uint256 public flushActivator;

    /// @dev A list of all of the vaults. The last element of the list is the vault that is currently being used for
    /// deposits and withdraws. Vaults before the last element are considered inactive and are expected to be cleared.
    VaultV2.List private _vaults;

    /// @dev The context shared between the CDPs.
    CDPv2.Context private _ctx;

    /// @dev A mapping of all of the user CDPs. If a user wishes to have multiple CDPs they will have to either
    /// create a new address or set up a proxy contract that interfaces with this contract.
    mapping(address => CDPv2.Data) private _cdps;

    struct HarvestInfo {
        uint256 lastHarvestPeriod; // Measured in seconds
        uint256 lastHarvestAmount; // Measured in USDC.
    }

    uint256 public lastHarvest; // timestamp
    HarvestInfo public harvestInfo;

    uint256 public HARVEST_INTERVAL; 

    // Events.

    event GovernanceUpdated(address governance);

    event PendingGovernanceUpdated(address pendingGovernance);

    event SentinelUpdated(address sentinel);

    event ActiveVaultUpdated(IVaultAdapterV2 indexed adapter);

    event RewardsUpdated(address treasury);

    event HarvestFeeUpdated(uint256 fee);

    event StakingUpdated(address stakingContract);

    event StakingFeeUpdated(uint256 stakingFee);

    event FlushActivatorUpdated(uint256 flushActivator);

    event AuxPriceRouterUpdated(address router);

    event TokensDeposited(address indexed account, uint256 amount);

    event EmergencyExitUpdated(bool status);

    event FundsFlushed(uint256 amount);

    event FundsHarvested(uint256 withdrawnAmount, uint256 decreasedValue, uint256 realizedAux);

    event TokensWithdrawn(address indexed account, uint256 requestedAmount, uint256 withdrawnAmount, uint256 decreasedValue);

    event FundsRecalled(uint256 indexed vaultId, uint256 withdrawnAmount, uint256 decreasedValue);

    event AuxClaimed(address indexed account, uint256 auxAmount);

    event HarvestIntervalUpdated(uint256 interval);

    event AutoCompound(address indexed account, uint256 auxYield, uint256 usdcAmount);

    constructor(IMintableERC20 _usdctoken, IMintableERC20 _auxtoken, address _governance, address _sentinel) public {
        require(_governance != ZERO_ADDRESS, "Error: Cannot be the null address");
        require(_sentinel != ZERO_ADDRESS, "Error: Cannot be the null address");

        usdcToken = _usdctoken;
        auxToken = _auxtoken;

        sentinel = _sentinel;
        governance = _governance;
        flushActivator = 10000 * 1e6; // Ten thousand

        HARVEST_INTERVAL = 43200; // In seconds, equals 12 hours. Should be modifiable by gov.

        _ctx.accumulatedYieldWeight = FixedPointMath.FixedDecimal(0);
    }

    /// @dev Checks that the current message sender or caller is the governance address.
    ///
    ///
    modifier onlyGov() {
        require(msg.sender == governance, "GsdLending: only governance");
        _;
    }

    /// @dev Checks that the contract is in an initialized state.
    ///
    /// This is used over a modifier to reduce the size of the contract
    modifier expectInitialized() {
        require(initialized, "GsdLending: not initialized");
        _;
    }

    /// @dev Sets the pending governance.
    ///
    /// This function reverts if the new pending governance is the zero address or the caller is not the current
    /// governance. This is to prevent the contract governance being set to the zero address which would deadlock
    /// privileged contract functionality.
    ///
    /// @param _pendingGovernance the new pending governance.
    function setPendingGovernance(address _pendingGovernance) external onlyGov {
        require(_pendingGovernance != ZERO_ADDRESS, "Error: Cannot be the null address");

        pendingGovernance = _pendingGovernance;

        emit PendingGovernanceUpdated(_pendingGovernance);
    }

    /// @dev Accepts the role as governance.
    ///
    /// This function reverts if the caller is not the new pending governance.
    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "Error: Sender is not pendingGovernance");

        //address _pendingGovernance = pendingGovernance;
        governance = pendingGovernance;
        pendingGovernance = address(0);

        emit GovernanceUpdated(governance);
    }

    function setSentinel(address _sentinel) external onlyGov {
        require(_sentinel != ZERO_ADDRESS, "Error: Cannot be the null address");

        sentinel = _sentinel;

        emit SentinelUpdated(_sentinel);
    }

    /// @dev Initializes the contract.
    ///
    /// This function checks that the transmuter and rewards have been set and sets up the active vault.
    ///
    /// @param _adapter the vault adapter of the active vault.
    function initialize(IVaultAdapterV2 _adapter) external onlyGov {
        require(!initialized, "GsdLending: already initialized");
        
        require(staking != ZERO_ADDRESS, "Error: Cannot be the null address");
        require(rewards != ZERO_ADDRESS, "Error: Cannot be the null address");

        _updateActiveVault(_adapter);
        initialized = true;
    }

    /// @dev Migrates the system to a new vault.
    ///
    /// This function reverts if the vault adapter is the zero address, if the token that the vault adapter accepts
    /// is not the token that this contract defines as the parent asset, or if the contract has not yet been initialized.
    ///
    /// @param _adapter the adapter for the vault the system will migrate to.
    function migrate(IVaultAdapterV2 _adapter) external expectInitialized onlyGov {
        _updateActiveVault(_adapter);
    }

    /// @dev Updates the active vault.
    ///
    /// This function reverts if the vault adapter is the zero address, if the token that the vault adapter accepts
    /// is not the token that this contract defines as the parent asset, or if the contract has not yet been initialized.
    ///
    /// @param _adapter the adapter for the new active vault.
    function _updateActiveVault(IVaultAdapterV2 _adapter) internal {
        require(_adapter != IVaultAdapterV2(ZERO_ADDRESS), "Error: Cannot be the null address");
        require(_adapter.token() == usdcToken, "GsdLending: token mismatch");

        bool check = IMintableERC20(usdcToken).approve(address(_adapter), type(uint256).max);
        require(check, "Error: Check reverted");

        _vaults.push(VaultV2.Data({adapter: _adapter, totalDeposited: 0}));

        emit ActiveVaultUpdated(_adapter);
    }

    // Sets the AUXUSDC price getter from TraderJoe DEX.
    function setAuxPriceRouterAddress(address router) external onlyGov {
        require(router != address(0), "Error: Cannot be the null address");

        _router = PriceRouter.Router({_router: router, _aux: address(auxToken), _usdc: address(usdcToken)});

        emit AuxPriceRouterUpdated(router);
    }

    /// @dev Sets if the contract should enter emergency exit mode.
    ///
    /// @param _emergencyExit if the contract should enter emergency exit mode.
    function setEmergencyExit(bool _emergencyExit) external {
        require(msg.sender == governance || msg.sender == sentinel, "Error: Caller not allowed");

        emergencyExit = _emergencyExit;

        emit EmergencyExitUpdated(_emergencyExit);
    }

    /// @dev Sets the flushActivator.
    ///
    /// @param _flushActivator the new flushActivator.
    function setFlushActivator(uint256 _flushActivator) external onlyGov {
        flushActivator = _flushActivator;

        emit FlushActivatorUpdated(_flushActivator);
    }

    /// @dev Sets the staking contract.
    ///
    /// This function reverts if the new staking contract is the zero address or the caller is not the current governance.
    ///
    /// @param _staking the new rewards contract.
    function setStaking(address _staking) external onlyGov {
        // Check that the staking address is not the zero address. Setting the staking to the zero address would break
        // transfers to the address because of `safeTransfer` checks.
        require(_staking != ZERO_ADDRESS, "Error: Cannot be the null address");

        staking = _staking;

        emit StakingUpdated(_staking);
    }

    /// @dev Sets the staking fee.
    ///
    /// This function reverts if the caller is not the current governance.
    ///
    /// @param _stakingFee the new staking fee.
    function setStakingFee(uint256 _stakingFee) external onlyGov {
        // Check that the staking fee is within the acceptable range. Setting the staking fee greater than 100% could
        // potentially break internal logic when calculating the staking fee.
        require(_stakingFee.add(harvestFee) <= PERCENT_RESOLUTION, "GsdLending: Fee above maximum");

        stakingFee = _stakingFee;

        emit StakingFeeUpdated(_stakingFee);
    }

    /// @dev Sets the rewards contract.
    ///
    /// This function reverts if the new rewards contract is the zero address or the caller is not the current governance.
    ///
    /// @param _rewards the new rewards contract.
    function setRewards(address _rewards) external onlyGov {
        // Check that the rewards address is not the zero address. Setting the rewards to the zero address would break
        // transfers to the address because of `safeTransfer` checks.
        require(_rewards != ZERO_ADDRESS, "Error: Cannot be the null address");

        rewards = _rewards;

        emit RewardsUpdated(_rewards);
    }

    /// @dev Sets the harvest fee.
    ///
    /// This function reverts if the caller is not the current governance.
    ///
    /// @param _harvestFee the new harvest fee.
    function setHarvestFee(uint256 _harvestFee) external onlyGov {
        // Check that the harvest fee is within the acceptable range. Setting the harvest fee greater than 100% could
        // potentially break internal logic when calculating the harvest fee.
        require(_harvestFee.add(stakingFee) <= PERCENT_RESOLUTION, "GsdLending: Fee above maximum");

        harvestFee = _harvestFee;
        emit HarvestFeeUpdated(_harvestFee);
    }

    function setHarvestInterval(uint256 _interval) external onlyGov {
        HARVEST_INTERVAL = _interval;
        
        emit HarvestIntervalUpdated(_interval);
    }

    /// @dev Flushes buffered tokens to the active vault.
    ///
    /// This function reverts if an emergency exit is active. This is in place to prevent the potential loss of
    /// additional funds.
    ///
    /// @return the amount of tokens flushed to the active vault.
    function flush() external nonReentrant expectInitialized returns (uint256) {
        // Prevent flushing to the active vault when an emergency exit is enabled to prevent potential loss of funds if
        // the active vault is poisoned for any reason.
        require(!emergencyExit, "Error: Emergency pause enabled");

        return _flushActiveVault();
    }

    /// @dev Internal function to flush buffered tokens to the active vault.
    ///
    /// This function reverts if an emergency exit is active. This is in place to prevent the potential loss of
    /// additional funds.
    ///
    /// @return the amount of tokens flushed to the active vault.
    function _flushActiveVault() internal returns (uint256) {
        VaultV2.Data storage _activeVault = _vaults.last();
        uint256 _depositedAmount = _activeVault.depositAll();

        emit FundsFlushed(_depositedAmount);

        return _depositedAmount;
    }

    function harvest(uint256 _vaultId) public expectInitialized returns (uint256, uint256, uint256) {
        VaultV2.Data storage _vault = _vaults.get(_vaultId);
        HarvestInfo storage _harvest = harvestInfo;

        uint256 _realisedAux;

        //console.log("Harvesting in Lending contract...");
        (uint256 _harvestedAmount, uint256 _decreasedValue) = _vault.harvest(address(this));
        //console.log("Harvest done in Lending contract");

        if(_harvestedAmount > 0) {
            //console.log("Harvested USDC:", _harvestedAmount);

            _realisedAux = _router.swapUsdcForAux(_harvestedAmount);
            require(_realisedAux > 0, "Error: Swap issues");
            //console.log("Swapped AUX:", _realisedAux);

            uint256 _stakingAmount = _realisedAux.mul(stakingFee).div(PERCENT_RESOLUTION);
            uint256 _feeAmount = _realisedAux.mul(harvestFee).div(PERCENT_RESOLUTION);
            uint256 _distributeAmount = _realisedAux.sub(_feeAmount).sub(_stakingAmount);
            //console.log("Distribute amount:", _distributeAmount);
            //console.log("Deposited USDC:", totalDepositedUsdc);

            FixedPointMath.FixedDecimal memory _weight = FixedPointMath.fromU256(_distributeAmount).div(totalDepositedUsdc);
            //console.log("Weight:", _weight.x);

            _ctx.accumulatedYieldWeight = _ctx.accumulatedYieldWeight.add(_weight);

            if (_feeAmount > 0) {
                auxToken.safeTransfer(rewards, _feeAmount);
            }

            if (_stakingAmount > 0) {
                _distributeToStaking(_stakingAmount);
            }       

            _harvest.lastHarvestPeriod = block.timestamp.sub(lastHarvest);
            _harvest.lastHarvestAmount = _harvestedAmount;
            
            lastHarvest = block.timestamp;
        }

        emit FundsHarvested(_harvestedAmount, _decreasedValue, _realisedAux);

        return (_harvestedAmount, _decreasedValue, _realisedAux);
    }

    // User methods.

    /// @dev Deposits collateral into a CDP.
    ///
    /// This function reverts if an emergency exit is active. This is in place to prevent the potential loss of
    /// additional funds.
    ///
    /// @param _amount the amount of collateral to deposit.
    function deposit(uint256 _amount) external nonReentrant expectInitialized {
        require(!emergencyExit, "Error: Emergency pause enabled");

        CDPv2.Data storage _cdp = _cdps[msg.sender];

        if(totalDepositedUsdc > 0 && block.timestamp >= lastHarvest + HARVEST_INTERVAL) {
            harvest(_vaults.lastIndex());
        }

        _cdp.update(_ctx); 

        usdcToken.safeTransferFrom(msg.sender, address(this), _amount);

        if (_amount >= flushActivator) {
            _flushActiveVault();
        }

        if(totalDepositedUsdc == 0) {
            lastHarvest = block.timestamp;
        }

        totalDepositedUsdc = totalDepositedUsdc.add(_amount);

        _cdp.totalDeposited = _cdp.totalDeposited.add(_amount);
        _cdp.lastDeposit = block.timestamp; 

        emit TokensDeposited(msg.sender, _amount);
    }

    /// @dev Claim sender's yield from active vault.
    ///
    /// @return the amount of funds that were harvested from active vault.
    function claim() external nonReentrant expectInitialized returns (uint256) {
        CDPv2.Data storage _cdp = _cdps[msg.sender];

        if(block.timestamp >= lastHarvest + HARVEST_INTERVAL) {
            harvest(_vaults.lastIndex());

            //console.log("Lending contract balance after harvesting:", IMintableERC20(auxToken).balanceOf(address(this)));
        }

        _cdp.update(_ctx);
        //console.log("New user total credit:", _cdp.totalCredit);

        // Keep on going.
        //(uint256 _withdrawnAmount,) = _withdrawFundsTo(msg.sender, _cdp.totalCredit);
        uint256 _auxYield = _cdp.totalCredit;
        _cdp.totalCredit = 0;

        IMintableERC20(auxToken).safeTransfer(msg.sender, _auxYield);
        emit AuxClaimed(msg.sender, _auxYield);

        return _auxYield;
    }

    function autoCompound() external nonReentrant expectInitialized returns (uint256) {
        require(!emergencyExit, "Error: Emergency pause enabled");

        CDPv2.Data storage _cdp = _cdps[msg.sender];

        if(totalDepositedUsdc > 0 && block.timestamp >= lastHarvest + HARVEST_INTERVAL) {
            harvest(_vaults.lastIndex());
        }

        _cdp.update(_ctx); 

        // First swap user AUX credit back into USDC.
        uint256 auxAmount = _cdp.totalCredit;
        require(auxAmount > 0, "Error: Null AUX to auto-compound");
        _cdp.totalCredit = 0;

        uint256 _realisedUsdc = _router.swapAuxForUsdc(auxAmount);
        require(_realisedUsdc > 0, "Error: Swap issues");

        // Then deposit user USDC on the vault.
        if (_realisedUsdc >= flushActivator) {
            _flushActiveVault();
        }

        totalDepositedUsdc = totalDepositedUsdc.add(_realisedUsdc);

        _cdp.totalDeposited = _cdp.totalDeposited.add(_realisedUsdc);
        _cdp.lastDeposit = block.timestamp; 

        // Missing event for auto compounding.
        emit AutoCompound(msg.sender, auxAmount, _realisedUsdc);
    }

    /// @dev Attempts to withdraw part of a CDP's collateral.
    ///
    /// This function reverts if a deposit into the CDP was made in the same block. This is to prevent flash loan attacks
    /// on other internal or external systems.
    ///
    /// @param _amount the amount of collateral to withdraw.
    function withdraw(uint256 _amount) external nonReentrant expectInitialized returns (uint256, uint256) {
        CDPv2.Data storage _cdp = _cdps[msg.sender];
        require(block.timestamp > _cdp.lastDeposit, "Error: Flash loans not allowed");

        if(block.timestamp >= lastHarvest + HARVEST_INTERVAL) {
            harvest(_vaults.lastIndex());
        }

        _cdp.update(_ctx);

        (uint256 _withdrawnAmount, uint256 _decreasedValue) = _withdrawFundsTo(msg.sender, _amount);

        totalDepositedUsdc = totalDepositedUsdc.sub(_decreasedValue, "Exceeds maximum withdrawable amount");
        _cdp.totalDeposited = _cdp.totalDeposited.sub(_decreasedValue, "Exceeds withdrawable amount");

        emit TokensWithdrawn(msg.sender, _amount, _withdrawnAmount, _decreasedValue);

        return (_withdrawnAmount, _decreasedValue);
    }

    /// @dev Recalls an amount of deposited funds from a vault to this contract.
    ///
    /// @param _vaultId the identifier of the recall funds from.
    ///
    /// @return the amount of funds that were recalled from the vault to this contract and the decreased vault value.
    function recall(uint256 _vaultId, uint256 _amount) external nonReentrant expectInitialized returns (uint256, uint256) {
        return _recallFunds(_vaultId, _amount);
    }

    /// @dev Recalls all the deposited funds from a vault to this contract.
    ///
    /// @param _vaultId the identifier of the recall funds from.
    ///
    /// @return the amount of funds that were recalled from the vault to this contract and the decreased vault value.
    function recallAll(uint256 _vaultId) external nonReentrant expectInitialized returns (uint256, uint256) {
        VaultV2.Data storage _vault = _vaults.get(_vaultId);
        return _recallFunds(_vaultId, _vault.totalDeposited);
    }

    /// @dev Recalls an amount of funds from a vault to this contract.
    ///
    /// @param _vaultId the identifier of the recall funds from.
    /// @param _amount  the amount of funds to recall from the vault.
    ///
    /// @return the amount of funds that were recalled from the vault to this contract and the decreased vault value.
    function _recallFunds(uint256 _vaultId, uint256 _amount) internal returns (uint256, uint256) {
        require(emergencyExit || msg.sender == governance || _vaultId != _vaults.lastIndex(), "GsdLending: user does not have permission to recall funds from active vault");

        VaultV2.Data storage _vault = _vaults.get(_vaultId);
        (uint256 _withdrawnAmount, uint256 _decreasedValue) = _vault.withdraw(address(this), _amount);

        emit FundsRecalled(_vaultId, _withdrawnAmount, _decreasedValue);

        return (_withdrawnAmount, _decreasedValue);
    }

    /// @dev Attempts to withdraw funds from the active vault to the recipient.
    ///
    /// Funds will be first withdrawn from this contracts balance and then from the active vault. This function
    /// is different from `recallFunds` in that it reduces the total amount of deposited tokens by the decreased
    /// value of the vault.
    ///
    /// @param _recipient the account to withdraw the funds to.
    /// @param _amount    the amount of funds to withdraw.
    function _withdrawFundsTo(address _recipient, uint256 _amount) internal returns (uint256, uint256) {
        // Pull the funds from the buffer.
        uint256 _bufferedAmount = Math.min(_amount, usdcToken.balanceOf(address(this)));

        if (_recipient != address(this) && _bufferedAmount > 0) {
            usdcToken.safeTransfer(_recipient, _bufferedAmount);
        }

        uint256 _totalWithdrawn = _bufferedAmount;
        uint256 _totalDecreasedValue = _bufferedAmount;

        uint256 _remainingAmount = _amount.sub(_bufferedAmount);

        // Pull the remaining funds from the active vault.
        if (_remainingAmount > 0) {
            VaultV2.Data storage _activeVault = _vaults.last();

            (uint256 _withdrawAmount, uint256 _decreasedValue) = _activeVault.withdraw(_recipient, _remainingAmount);

            _totalWithdrawn = _totalWithdrawn.add(_withdrawAmount);
            _totalDecreasedValue = _totalDecreasedValue.add(_decreasedValue);
        }

        return (_totalWithdrawn, _totalDecreasedValue);
    }

    /// @dev sends tokens to the staking contract
    function _distributeToStaking(uint256 amount) internal {
        bool check = auxToken.approve(staking, amount);
        require(check, "Error: Check reverted");

        IGsdStaking(staking).deposit(amount);
    }

    // Getters.
    function accumulatedYieldWeight() external view returns (FixedPointMath.FixedDecimal memory) {
        return _ctx.accumulatedYieldWeight;
    }

    /// @dev Gets the number of vaults in the vault list.
    ///
    /// @return the vault count.
    function vaultCount() external view returns (uint256) {
        return _vaults.length();
    }    

    /// @dev Get the adapter of a vault.
    ///
    /// @param _vaultId the identifier of the vault.
    ///
    /// @return the vault adapter.
    function getVaultAdapter(uint256 _vaultId) external view returns (IVaultAdapterV2) {
        VaultV2.Data storage _vault = _vaults.get(_vaultId);
        return _vault.adapter;
    }

    /// @dev Get the total amount of the parent asset that has been deposited into a vault.
    ///
    /// @param _vaultId the identifier of the vault.
    ///
    /// @return the total amount of deposited tokens.
    function getVaultTotalDeposited(uint256 _vaultId) external view returns (uint256) {
        VaultV2.Data storage _vault = _vaults.get(_vaultId);
        return _vault.totalDeposited;
    }

    function getUserCDPData(address account) external view returns (CDPv2.Data memory) {
        CDPv2.Data storage _cdp = _cdps[account];
        return _cdp;
    }

    function getAccruedInterest(address account) external view returns (uint256) {
        CDPv2.Data storage _cdp = _cdps[account];

        uint256 _earnedYield = _cdp.getEarnedYield(_ctx);
        return _cdp.totalCredit.add(_earnedYield);
    }
}