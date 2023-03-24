// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IELP.sol";
import "./interfaces/IMintable.sol";
import "../core/interfaces/IVault.sol";
import "../staking/interfaces/IRewardTracker.sol";

contract ELP is IERC20, IMintable, ReentrancyGuard, IELP, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;
    uint256 public nonStakingSupply;

    // address public EUSDDistributor;
    mapping (address => bool) public override isMinter;
   


    mapping (address => uint256) public balances;
    mapping (address => uint256) public stakedAmount;
    mapping (address => mapping (address => uint256)) public allowances;

    mapping (address => bool) public nonStakingAccounts;

    bool public inPrivateTransferMode;
    mapping (address => bool) public isHandler;


    //----- start of EDIST


    uint256 public constant PRICE_TO_EUSD = 10 ** 12; //ATTENTION: must be same as vault.
    uint256 public constant fundingInterval = 24 hours; //ATTENTION: must be same as vault.
    // uint256 public stasticTimestamp;

    // mapping (uint256 => uint256) public cumulateFunding;

    bool public isSwapEnabled = true;
    bool public isInitialized;


    address public override vault;
    address public eusd;
    address public edeStakingPool;
    address public elpStakingTracker;
    uint256 public feeToPoolRatio = 4000; // 40%;
    uint256 public feeToPoolPrec = 10000; // 100%;
    uint256 public EUSDTotalAmount;
    uint256 public EUSDEDEReward;
    uint256 public EUSDELPReward;
    uint256 public EUSDEDERewardClaimed;
    uint256 public EUSDELPRewardClaimed;   
    mapping (address => uint256) public lastAddedAt;
    mapping (address => bool) public isManager;


    address[] public allWhitelistedTokens;
    mapping (address => bool) public whitelistedTokens;
    mapping (address => uint256) public tokenDecimals;

    uint256 public lastDistributionTime;
    uint256 public cumulativeRewardPerToken;
    uint256 public constant REWARD_PRECISION = 10 ** 20;



    mapping (address => uint256) public claimableReward;
    mapping (address => uint256) public previousCumulatedRewardPerToken;
    mapping (address => uint256) public cumulativeRewards;


    event buyESUD(
        address account,
        address token,
        uint256 amount,
        uint256 fee
    );

    event sellESUD(
        address account,
        address token,
        uint256 amount,
        uint256 fee
    );
    //----- end of EDIST


    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }


    modifier onlyMinter() {
        require(isMinter[msg.sender], "forbidden");
        _;
    }

    function setMinter(address _minter, bool _isActive) external override onlyOwner {
        isMinter[_minter] = _isActive;
    }

    function setFeeToPoolRatio( uint256 _feeToPoolRatio) external onlyOwner {
        require(_feeToPoolRatio < feeToPoolPrec, "x");
        feeToPoolRatio = _feeToPoolRatio;
    }

    function mint(address _account, uint256 _amount) external override onlyMinter {
        _updateRewardsLight(_account);
        _mint(_account, _amount);
    }

    function burn(address , uint256 _amount) external override {
        // require(msg.sender == _account, "unmached burn account");
        _updateRewardsLight(msg.sender);
        _burn(msg.sender, _amount);
    }

    function setInfo(string memory _name, string memory _symbol) external onlyOwner {
        name = _name;
        symbol = _symbol;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        _updateRewards(_account);
        IERC20(_token).safeTransfer(_account, _amount);
    }


    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }


    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        require(msg.sender!= _recipient, "Self transfer is not allowed");
        _updateRewards(msg.sender);
        _updateRewards(_recipient);
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }
    

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        _updateRewards(_sender);
        _updateRewards(_recipient);
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }
        uint256 nextAllowance = allowances[_sender][msg.sender].sub(_amount, "ELP: transfer amount exceeds allowance");
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "ELP: mint to the zero address");


        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);

        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "ELP: burn from the zero address");

        balances[_account] = balances[_account].sub(_amount, "ELP: burn amount exceeds balance");
        totalSupply = totalSupply.sub(_amount);

        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        require(_sender != address(0), "ELP: transfer from the zero address");
        require(_recipient != address(0), "ELP: transfer to the zero address");

        if (inPrivateTransferMode) {
            require(isHandler[msg.sender], "ELP: msg.sender not whitelisted");
        }


        balances[_sender] = balances[_sender].sub(_amount, "ELP: transfer amount exceeds balance");
        balances[_recipient] = balances[_recipient].add(_amount);

        if (nonStakingAccounts[_sender]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }
        if (nonStakingAccounts[_recipient]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }

        emit Transfer(_sender, _recipient,_amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "ELP: approve from the zero address");
        require(_spender != address(0), "ELP: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    // function _updateRewards(address _account) private {
    //     if (EUSDDistributor != address(0)){
    //         IEUSDDistributor(EUSDDistributor).updateRewards(_account);
    //     }
    // }


    //-------- start of EDIST
    function initialize(
        address _vault,
        address _eusd,
        uint256 _eusdDecimals
    ) external onlyOwner {
        require(!isInitialized, "already initialized");
        isInitialized = true;
        eusd = _eusd;
        vault =_vault;
        tokenDecimals[eusd] = _eusdDecimals;
    }

    function updateStakingAmount(address _account, uint256 _amount) external override {
        require(msg.sender == elpStakingTracker, "invalid update handler");
        stakedAmount[_account] = _amount;
    }

    function setStakingPoolAddress(address _pool) external onlyOwner {
        // require(_pool != address(0), "invalid address")
        edeStakingPool = _pool;
    }
    function setELPStakingTracker(address _elppool) external onlyOwner {
        elpStakingTracker = _elppool;
    }
    function setManager(address _manager, bool _isManager) external onlyOwner {
        isManager[_manager] = _isManager;
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _validateManager() private view {
        require(isManager[msg.sender], "not manager");
    }

    function _validateInWhitelist(address _token) private view {
        require(whitelistedTokens[_token], "Whiltelist required");
    }

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals
    ) external onlyOwner {
        // increment token count for the first time
        if (!whitelistedTokens[_token]) {
            allWhitelistedTokens.push(_token);
        }
        whitelistedTokens[_token] = true;
        tokenDecimals[_token] = _tokenDecimals;
    }

    // function getFeeAum() public view returns (uint256) {
    //     uint256 length = allWhitelistedTokens.length;
    //     uint256 aum = 0;

    //     for (uint256 i = 0; i < length; i++) {
    //         address token = allWhitelistedTokens[i];
    //         bool isWhitelisted = whitelistedTokens[token];
    //         if (!isWhitelisted) {
    //             continue;
    //         }
    //         uint256 price = IVault(vault).getMinPrice(token);

    //         uint256 poolAmount = IVault(vault).feeReserves(token);

    //         uint256 _decimalsTk = tokenDecimals[token];
    //         aum = aum.add(poolAmount.mul(price).div(10 ** _decimalsTk));
    //     }
    //     return aum;
    // }

    function USDbyFee( ) external override view returns (uint256) {
        return IVault(vault).feeReservesUSD();
    }

    function TokenFeeReserved(address _token) external override view returns (uint256) {
        return IVault(vault).feeReserves( _token).sub(IVault(vault).feeSold( _token));
    }


    function _updateRewardsLight(address _account) private {
        uint256 accountAmount = balances[_account].add(stakedAmount[_account]);
        uint256 accountReward = accountAmount.mul(cumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])).div(REWARD_PRECISION);
        uint256 _claimableReward = claimableReward[_account].add(accountReward);
        claimableReward[_account] = _claimableReward;
        previousCumulatedRewardPerToken[_account] = cumulativeRewardPerToken;
    }

    function _updateRewards(address _account) private {
        uint256 blockReward = _pendingRewards();
        lastDistributionTime = block.timestamp;

        uint256 supply = totalSupply;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (supply > 0 && blockReward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(blockReward.mul(REWARD_PRECISION).div(supply));
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }
        if (blockReward > 0){
        // console.log("blockReward Reward: %s", blockReward);
        // console.log("=+++++>>>_updateRewards : _cumulativeRewardPerToken : %s", _cumulativeRewardPerToken);

        }

        if (_account != address(0)) {
            // console.log("UpdAccount : [%s]: %s",_account,  previousCumulatedRewardPerToken[_account] );
            uint256 accountAmount = balances[_account].add(stakedAmount[_account]);
            uint256 accountReward = accountAmount.mul(_cumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])).div(REWARD_PRECISION);
            uint256 _claimableReward = claimableReward[_account].add(accountReward);

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && accountAmount > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account].add(accountReward);
                cumulativeRewards[_account] = nextCumulativeReward;
            }
            
        }
    }


    function claim(address _receiver) public nonReentrant returns (uint256) {
        // console.log("TOTAl EUSD: %s", EUSDELPReward);
        return _claim(msg.sender, _receiver);
    }

    function claimForAccount(address _account) public nonReentrant override returns (uint256){
        return _claim(_account, _account);

    }

    function claimable(address _account) external override view returns (uint256) {
        uint256 _mintEUSDAmount = IVault(vault).claimableFeeReserves().div(PRICE_TO_EUSD);
        uint256 amountToEDEPool = _mintEUSDAmount.mul(feeToPoolRatio).div(feeToPoolPrec);
        uint256 thisRewardAmount = _mintEUSDAmount.sub(amountToEDEPool);

        uint256 supply = totalSupply;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (supply > 0 && thisRewardAmount > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(thisRewardAmount.mul(REWARD_PRECISION).div(supply));
        }
        uint256 accountAmount = balances[_account].add(stakedAmount[_account]);
        uint256 accountReward = accountAmount.mul(_cumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])).div(REWARD_PRECISION);
        uint256 _claimableReward = claimableReward[_account].add(accountReward);
        return _claimableReward;
    }

    function _claim(address _account, address _receiver) private returns (uint256) {
        _updateRewards(_account);
        uint256 tokenAmount = claimableReward[_account];
        if (tokenAmount > 0) {
            require(EUSDELPRewardClaimed.add(tokenAmount) <= EUSDELPReward, "EUSD Reward out of range");
            claimableReward[_account] = 0;
            EUSDELPRewardClaimed = EUSDELPRewardClaimed.add(tokenAmount);
            IMintable(eusd).mint(_receiver, tokenAmount);
            // IERC20(eusd).safeTransfer(_receiver, tokenAmount);
        }
        return tokenAmount;
    }



    function _pendingRewards() private  returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 _mintEUSDAmount = IVault(vault).claimFeeReserves().div(PRICE_TO_EUSD);
        if (_mintEUSDAmount < 1){
            return 0;
        }

        EUSDTotalAmount = EUSDTotalAmount.add(_mintEUSDAmount);

        uint256 amountToEDEPool = _mintEUSDAmount.mul(feeToPoolRatio).div(feeToPoolPrec);
        if ( amountToEDEPool > 0){
            EUSDEDEReward = EUSDEDEReward.add(amountToEDEPool);
        }
        uint256 thisRewardAmount = _mintEUSDAmount.sub(amountToEDEPool);
        EUSDELPReward = EUSDELPReward.add(thisRewardAmount);
        // uint256 timeCountID = block.timestamp.div(fundingInterval);
        // cumulateFunding[timeCountID] = cumulateFunding[timeCountID].add(thisRewardAmount);

        return thisRewardAmount;
    }

    function getFeeAmount(uint64 _stasticDays, uint64 _shiftDays) external view returns (uint256) {
        require(_stasticDays > 0 && _stasticDays < 30, "invalid days");
        require(_shiftDays >= 0 && _shiftDays < 30, "invalid _shiftDays");
        uint256 currentIndex = block.timestamp.div(fundingInterval).sub(_shiftDays);
       
        uint256 _feeTotal = 0;
        for (uint64 i = 0; i <_stasticDays; i++ ){
            _feeTotal = _feeTotal.add(IVault(vault).feeReservesRecord(currentIndex.sub(i)));
        }

        return _feeTotal.div(PRICE_TO_EUSD);//.mul(365).div(_stasticDays);
    }


    function adjustForEUSDDecimals(uint256 _amount, address _tokenDiv) public view returns (uint256) {
        return _amount.mul(10 ** tokenDecimals[eusd]).div(10 ** tokenDecimals[_tokenDiv]);
    }


    function withdrawToEDEPool() external override returns (uint256){
        uint256 extAmount = 0;
        if (edeStakingPool!= (address(0)) && EUSDEDEReward > EUSDEDERewardClaimed){
            _updateRewards(address(0));
            extAmount = EUSDEDEReward.sub(EUSDEDERewardClaimed);
            IMintable(eusd).mint(edeStakingPool, extAmount);
            EUSDEDERewardClaimed = EUSDEDEReward;
        }
        return extAmount;
    }






}