// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./library/NewSafeERC20.sol";
import "./interface/IStrategy.sol";
import "./interface/IAutoFarm.sol";
import "./AccessControl.sol";

contract TimelockController is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    mapping(bytes32 => uint256) private _timestamps;
    uint256 public minDelay = 60; // seconds - to be increased in production
    uint256 public minDelayReduced = 30; // seconds - to be increased in production

    address payable public devWalletAddress;

    /**
     * @dev Emitted when a call is scheduled as part of operation `id`.
     */
    event SetScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev Emitted when operation `id` is cancelled.
     */
    event Cancelled(bytes32 indexed id);

    /**
     * @dev Emitted when the minimum delay for future operations is modified.
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    event MinDelayReducedChange(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev Initializes the contract with a given `minDelay`.
     */
    constructor(address _devWalletAddress) public {
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, DEFAULT_ADMIN_ROLE);

        //--------== Mainnet would be set 0x22267AD91Bf10e427601c25901f34700379720a0
        devWalletAddress = payable(_devWalletAddress);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, devWalletAddress);
        _setupRole(PROPOSER_ROLE, devWalletAddress);
        _setupRole(EXECUTOR_ROLE, devWalletAddress);

        emit MinDelayChange(0, minDelay);
    }

    /**
     * @dev Contract might receive/hold ETH as part of the maintenance process.
     */
    receive() external payable {}

    /**
     * @dev Returns whether an operation is pending or not.
     */
    function isOperationPending(bytes32 id) public view returns (bool pending) {
        return _timestamps[id] > _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns whether an operation is ready or not.
     */
    function isOperationReady(bytes32 id) public view returns (bool ready) {
        // solhint-disable-next-line not-rely-on-time
        return
            _timestamps[id] > _DONE_TIMESTAMP &&
            _timestamps[id] <= block.timestamp;
    }

    /**
     * @dev Returns whether an operation is done or not.
     */
    function isOperationDone(bytes32 id) public view returns (bool done) {
        return _timestamps[id] == _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns the minimum delay for an operation to become valid.
     *
     * This value can be changed by executing an operation that calls `updateDelay`.
     */
    function getMinDelay() public view returns (uint256 duration) {
        return minDelay;
    }

    /**
     * @dev Returns the identifier of an operation containing a batch of
     * transactions.
     */
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32 hash) {
        return keccak256(abi.encode(targets, values, datas, predecessor, salt));
    }

    function getTimestamp(bytes32 id) public view returns (uint256 timestamp) {
        return _timestamps[id];
    }

    function predecessorCk(
        bytes32 predecessor
    ) public view returns (bool, bool) {
        return (predecessor == bytes32(0), isOperationDone(predecessor));
    }

    //------------------------==
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32 hash) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function cancel(bytes32 id) public virtual {
        require(hasRole(PROPOSER_ROLE, msg.sender), "!PROPOSER_ROLE");
        require(
            isOperationPending(id),
            "TimelockController: operation cannot be cancelled"
        );
        delete _timestamps[id];

        emit Cancelled(id);
    }

    function _beforeCall(bytes32 predecessor) private view {
        require(
            predecessor == bytes32(0) || isOperationDone(predecessor),
            "TimelockController: missing dependency"
        );
    }

    function _afterCall(bytes32 id) private {
        require(
            isOperationReady(id),
            "TimelockController: operation is not ready"
        );
        _timestamps[id] = _DONE_TIMESTAMP;
    }

    function updateMinDelay(uint256 newDelay) external virtual {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        emit MinDelayChange(minDelay, newDelay);
        minDelay = newDelay;
    }

    function updateMinDelayReduced(uint256 newDelay) external virtual {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        emit MinDelayReducedChange(minDelayReduced, newDelay);
        minDelayReduced = newDelay;
    }

    function scheduleSet(
        address _autofarmAddress,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bytes32 predecessor,
        bytes32 salt
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");

        bytes32 id = keccak256(
            abi.encode(
                _autofarmAddress,
                _pid,
                _allocPoint,
                _withUpdate,
                predecessor,
                salt
            )
        );

        require(
            _timestamps[id] == 0 || _timestamps[id] == _DONE_TIMESTAMP,
            "TimelockController: operation scheduled but not executed yet"
        );

        _timestamps[id] = SafeMath.add(block.timestamp, minDelayReduced);
        emit SetScheduled(
            id,
            0,
            _pid,
            _allocPoint,
            _withUpdate,
            predecessor,
            minDelayReduced
        );
    }

    function executeSet(
        address _autofarmAddress,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        bytes32 id = keccak256(
            abi.encode(
                _autofarmAddress,
                _pid,
                _allocPoint,
                _withUpdate,
                predecessor,
                salt
            )
        );

        _beforeCall(predecessor);
        IAutoFarm(_autofarmAddress).set(_pid, _allocPoint, _withUpdate);
        _afterCall(id);
    }

    /**
     * @dev No timelock functions
     */
    function withdrawBNB() public payable {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        devWalletAddress.transfer(address(this).balance);
    }

    function withdrawBEP20(address _tokenAddress) public payable {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        uint256 tokenBal = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeIncreaseAllowance(devWalletAddress, tokenBal);
        IERC20(_tokenAddress).transfer(devWalletAddress, tokenBal);
    }

    function add(
        address _autofarmAddress,
        address _want,
        bool _withUpdate,
        address _strat
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IAutoFarm(_autofarmAddress).add(0, _want, _withUpdate, _strat); // allocPoint = 0. Schedule set (timelocked) to increase allocPoint.
    }

    function earn(address _stratAddress) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).earn();
    }

    function farm(address _stratAddress) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).farm();
    }

    function pause(address _stratAddress) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).pause();
    }

    function unpause(address _stratAddress) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).unpause();
    }

    function setEnableAddLiquidity(address _stratAddress, bool _status) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setEnableAddLiquidity(_status);
    }

    function setWITHDRAWALFee(
        address _stratAddress,
        uint256 _WITHDRAWAL_FEE
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setWITHDRAWALFee(_WITHDRAWAL_FEE);
    }

    function setControllerFee(
        address _stratAddress,
        uint256 _controllerFee
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setControllerFee(_controllerFee);
    }

    function setbuyBackRate(
        address _stratAddress,
        uint256 _buyBackRate
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setbuyBackRate(_buyBackRate);
    }

    function setReceieveFeeAddress(
        address _stratAddress,
        address _receiveFeeAddress
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setReceieveFeeAddress(_receiveFeeAddress);
    }

    function setGov(address _stratAddress, address _govAddress) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setGov(_govAddress);
    }

    function setOnlyGov(address _stratAddress, bool _onlyGov) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setOnlyGov(_onlyGov);
    }

    function setfundManager(
        address _stratAddress,
        address _fundManager
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setfundManager(_fundManager);
    }

    function setfundManager2(
        address _stratAddress,
        address _fundManager2
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setfundManager2(_fundManager2);
    }

    function setfundManager3(
        address _stratAddress,
        address _fundManager3
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setfundManager3(_fundManager3);
    }

    function setfundManager4(
        address _stratAddress,
        address _fundManager4
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IStrategy(_stratAddress).setfundManager4(_fundManager4);
    }

    function setAFIPerBlock(
        address _autofarmAddress,
        uint256 _inputAmt
    ) public {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "!EXECUTOR_ROLE");
        IAutoFarm(_autofarmAddress).setAFIPerBlock(_inputAmt);
    }
}