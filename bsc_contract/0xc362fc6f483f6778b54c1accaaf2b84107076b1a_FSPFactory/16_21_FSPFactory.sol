// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//     _______                        _       __   _____                 _                   ____  __      __  ____                        _____ __        __   _                 //
//    / ____(_)___  ____ _____  _____(_)___ _/ /  / ___/___  ______   __(_)_______  _____   / __ \/ /___ _/ /_/ __/___  _________ ___     / ___// /_____ _/ /__(_)___  ____ _     //
//   / /_  / / __ \/ __ `/ __ \/ ___/ / __ `/ /   \__ \/ _ \/ ___/ | / / / ___/ _ \/ ___/  / /_/ / / __ `/ __/ /_/ __ \/ ___/ __ `__ \    \__ \/ __/ __ `/ //_/ / __ \/ __ `/     //
//  / __/ / / / / / /_/ / / / / /__/ / /_/ / /   ___/ /  __/ /   | |/ / / /__/  __(__  )  / ____/ / /_/ / /_/ __/ /_/ / /  / / / / / /   ___/ / /_/ /_/ / ,< / / / / / /_/ /      //
// /_/   /_/_/ /_/\__,_/_/ /_/\___/_/\__,_/_/   /____/\___/_/    |___/_/\___/\___/____/  /_/   /_/\__,_/\__/_/  \____/_/  /_/ /_/ /_/   /____/\__/\__,_/_/|_/_/_/ /_/\__, /       //
//                                                                                                                                                                                //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../Interface/IRematic.sol";
import "../Interface/IFSPPool.sol";
import "../Interface/IFSPPoolDeployer.sol";

contract FSPFactory is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    mapping(address => address[]) public pools; // pool addresses created by pool owner
    mapping(address => uint256) public totalDepositAmount; // total RFX deposit amounts of all pools
    mapping(address => mapping(address => uint256))
        public stakedTokenDepositAmount;
    mapping(address => bool) public isPoolAddress;
    address public platformOwner;
    uint256 public poolCreateFee0;
    uint256 public poolCreateFee1;
    uint256 public poolCreateFee2;
    uint256 public poolCreateFee3;
    uint256 public depositFee1;
    uint256 public depositFee2;
    uint256 public reflectionClaimFee;
    uint256 public rewardClaimFee1;
    uint256 public rewardClaimFee2;
    uint256 public earlyWithdrawFee1;
    uint256 public earlyWithdrawFee2;
    uint256 public canceledWithdrawFee1;
    uint256 public canceledWithdrawFee2;
    uint256 public rewardRatio1; // 1 year Pool
    uint256 public rewardRatio2; // 180 days Pool
    uint256 public rewardRatio3; // 90 days Pool
    uint256 public rewardRatio4; // 30 days Pool
    address[] public allPools; // all created pool addresses
    address public RFXAddress; // RFX Smart Contract Address
    address public deployer;
    mapping(address => bool) public admins;

    event NewFSPPool(address indexed smartChef);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    function initialize(
        uint256[] memory _poolCreateFees,
        uint256[] memory _depositFees,
        uint256 _reflectionClaimFee,
        uint256[] memory _rewardClaimFees,
        uint256[] memory _earlyWithdrawFees,
        uint256[] memory _canceledWithdrawFees,
        uint256[] memory _rewardRatio
    ) public initializer {
        poolCreateFee0 = _poolCreateFees[0]; // 0.04 bnb
        poolCreateFee1 = _poolCreateFees[1]; // 0.03 bnb 
        poolCreateFee2 = _poolCreateFees[2]; // 0.02 bnb
        poolCreateFee3 = _poolCreateFees[3]; // 0.01 bnb
        depositFee1 = _depositFees[0]; // 0.0075 bnb
        depositFee2 = _depositFees[1]; // 0.012 bnb
        reflectionClaimFee = _reflectionClaimFee; // 0.001 bnb
        rewardClaimFee1 = _rewardClaimFees[0]; // 0.001 bnb
        rewardClaimFee2 = _rewardClaimFees[1]; // 0.002 bnb
        earlyWithdrawFee1 = _earlyWithdrawFees[0]; // 0.04bnb
        earlyWithdrawFee2 = _earlyWithdrawFees[1]; // 0.04 bnb
        canceledWithdrawFee1 = _canceledWithdrawFees[0]; // 0.008 bnb
        canceledWithdrawFee2 = _canceledWithdrawFees[1]; // 0.012 bnb
        rewardRatio1 = _rewardRatio[0]; // 100000 
        rewardRatio2 = _rewardRatio[1]; // 49310 
        rewardRatio3 = _rewardRatio[2]; // 24650 
        rewardRatio4 = _rewardRatio[3]; // 8291
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /*
     * @notice Deply the contract
     * @param _stakedToken: staked token address
     * @param _reflectionToken: _reflectionToken token address
     * @param _rewardSupply: Reward Supply Amount
     * @param _APYPercent: APY
     * @param _lockTimeType: Lock Time Type 
               0 - 1 year 
               1- 180 days 
               2- 90 days 
               3 - 30 days
     * @param _limitAmountPerUser: Pool limit per user in stakedToken
     * @param isPartition:
     * @param _isPrivate: default: false, private:true
     */
    function deployPool(
        address _stakedToken,
        address _reflectionToken,
        uint256 _rewardSupply,
        uint256 _APYPercent,
        uint256 _lockTimeType,
        uint256 _limitAmountPerUser,
        bool isPartition,
        bool _isPrivate
    ) external payable {
        require(
            _lockTimeType >= 0 && _lockTimeType < 4,
            "Lock Time Type is not correct"
        );
        require(
            getCreationFee(_lockTimeType) <= msg.value,
            "Pool Price is not correct."
        );
        require(
            IERC20MetadataUpgradeable(_stakedToken).totalSupply() >= 0,
            "token supply should be greater than zero"
        );
        if (_reflectionToken != address(0)) {
            require(
                IERC20MetadataUpgradeable(_reflectionToken).totalSupply() >= 0,
                "token supply should be greater than zero"
            );
        }
        require(
            _stakedToken != _reflectionToken,
            "Tokens must be be different"
        );

        // pass constructor argument
        bytes32 salt = keccak256(
            abi.encodePacked(_stakedToken, _reflectionToken, block.timestamp)
        );

        address newPoolAddress = IFSPPoolDeployer(deployer).createPool(salt, msg.sender);

        IFSPPool(newPoolAddress).initialize(
            _stakedToken,
            _reflectionToken,
            _rewardSupply,
            _APYPercent,
            _lockTimeType,
            _limitAmountPerUser,
            isPartition,
            _isPrivate
        );

        allPools.push(newPoolAddress);
        pools[msg.sender].push(newPoolAddress);
        isPoolAddress[newPoolAddress] = true;

        emit NewFSPPool(newPoolAddress);
    }

    function getDepositFee(bool _isReflection) external view returns (uint256) {
        return _isReflection ? depositFee1 : depositFee2;
    }

    function getRewardClaimFee(
        bool _isReflection
    ) external view returns (uint256) {
        return _isReflection ? rewardClaimFee1 : rewardClaimFee2;
    }

    function getEarlyWithdrawFee(
        bool _isReflection
    ) external view returns (uint256) {
        return _isReflection ? earlyWithdrawFee1 : earlyWithdrawFee2;
    }

    function getCanceledWithdrawFee(
        bool _isReflection
    ) external view returns (uint256) {
        return _isReflection ? canceledWithdrawFee1 : canceledWithdrawFee2;
    }

    function getReflectionFee() external view returns (uint256) {
        return reflectionClaimFee;
    }

    function getCreationFee(uint256 _type) public view returns (uint256) {
        require(_type >= 0 && _type < 4, "Invalid type");
        return
            _type == 0 ? poolCreateFee0 : _type == 1
                ? poolCreateFee1
                : _type == 2
                ? poolCreateFee2
                : poolCreateFee3;
    }

    function updatePoolCreateFee(
        uint256 _poolCreateFee0,
        uint256 _poolCreateFee1,
        uint256 _poolCreateFee2,
        uint256 _poolCreateFee3
    ) external onlyOwner {
        poolCreateFee0 = _poolCreateFee0;
        poolCreateFee1 = _poolCreateFee1;
        poolCreateFee2 = _poolCreateFee2;
        poolCreateFee3 = _poolCreateFee3;
    }

    function updateReflectionFees(
        uint256 _depositFee,
        uint256 _earlyWithdrawFee,
        uint256 _canceledWithdrawFee,
        uint256 _rewardClaimFee,
        uint256 _reflectionClaimFee
    ) external onlyOwner {
        depositFee1 = _depositFee;
        earlyWithdrawFee1 = _earlyWithdrawFee;
        canceledWithdrawFee1 = _canceledWithdrawFee;
        reflectionClaimFee = _reflectionClaimFee;
        rewardClaimFee1 = _rewardClaimFee;
    }

    function updateNonReflectionFees(
        uint256 _depositFee,
        uint256 _earlyWithdrawFee,
        uint256 _canceledWithdrawFee,
        uint256 _rewardClaimFee
    ) external onlyOwner {
        depositFee2 = _depositFee;
        earlyWithdrawFee2 = _earlyWithdrawFee;
        canceledWithdrawFee2 = _canceledWithdrawFee;
        rewardClaimFee2 = _rewardClaimFee;
    }

    function setPlatformOwner(address _platformOwner) external onlyOwner {
        platformOwner = _platformOwner;
    }

    function isPlatformOwner(address _admin) public view returns (bool) {
        return _admin == platformOwner;
    }

    function updateRFXAddress(address _RFXAddress) external onlyOwner {
        RFXAddress = _RFXAddress;
    }

    function updateTotalDepositAmount(
        address _user,
        uint256 _amount,
        bool _type
    ) public {
        require(isPoolAddress[msg.sender], "You are not Pool");
        _type
            ? totalDepositAmount[_user] += _amount
            : totalDepositAmount[_user] -= _amount;
    }

    function updateTokenDepositAmount(
        address _tokenAddress,
        address _user,
        uint256 _amount,
        bool _type
    ) public {
        require(isPoolAddress[msg.sender], "You are not Pool");
        _type
            ? stakedTokenDepositAmount[_tokenAddress][_user] += _amount
            : stakedTokenDepositAmount[_tokenAddress][_user] -= _amount;
    }

    function addAdmin(address _admin) public onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) public onlyOwner {
        admins[_admin] = false;
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     * @param to Address for ETH to be send to
     * @param value Amount of ETH to send
     */
    function _safeTransferETH(
        address to,
        uint256 value
    ) internal returns (bool) {
        (bool success, ) = to.call{value: value, gas: 30_000}(new bytes(0));
        return success;
    }

    /**
     * @notice Allows owner to withdraw ETH funds to an address
     * @dev wraps _user in payable to fix address -> address payable
     * @param to Address for ETH to be send to
     * @param amount Amount of ETH to send
     */
    function withdraw(address payable to, uint256 amount) public onlyOwner {
        require(_safeTransferETH(to, amount));
    }

    /**
     * @notice Allows ownder to withdraw any accident tokens transferred to contract
     * @param _tokenContract Address for the token
     * @param to Address for token to be send to
     * @param amount Amount of token to send
     */
    function withdrawToken(
        address _tokenContract,
        address to,
        uint256 amount
    ) external nonReentrant onlyOwner {
        IERC20MetadataUpgradeable(_tokenContract).safeTransfer(to, amount);
    }

    function setFSPPoolDeployer(address _deployer) external onlyOwner {
        require(deployer != _deployer, "same value already!");
        deployer = _deployer;
    }

    receive() external payable {
        // React to receiving ether
    }
}