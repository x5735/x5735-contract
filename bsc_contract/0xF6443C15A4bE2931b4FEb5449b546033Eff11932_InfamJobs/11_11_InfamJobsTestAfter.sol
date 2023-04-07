// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract InfamJobs is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSAUpgradeable for bytes32;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    string constant statusError =
        "The project doesn't exist or has wrong status";
    string constant participateError = "You are not a participant in the project";

    enum Status {
        Empty,
        New,
        Started,
        Declined,
        Approving,
        Finished,
        Rejected,
        Disputed,
        Failed
    }

    struct Order {
        address project;
        address enfluencer;
        address token;
        string name;
        uint256 cost;
        uint256 startDate;
        uint256 reviewPeriod;
        uint256 deadline;
        uint256 timeDone;
        uint256 timeApprove;
        uint256 fee;
        bool fromEnfluencer;
        Status status;
    }

    mapping(string => address) public tokens;
    mapping(uint256 => Order) public orders;

    uint256 public currentId;

    uint256 public acceptTime;
    uint256 public disputeTime;

    uint256 public fee;
    uint256 public precision;
    mapping(address=>uint256) public accumulatedFee;
    mapping(string=>bool) public acceptedTokens;
    mapping(address => uint256) public subscribers;

    event NewOrder(
        uint256 uuid,
        address enfluencer,
        address project,
        uint256 cost,
        string token,
        uint256 reviewPeriod,
        uint256 deadline,
        uint256 timestamp,
        bool fromEnfluenser,
        uint256 fee
    );
    event DisputeRejected(uint256 uuid);
    event DisputeConfirmed(uint256 uuid);
    event FundsClaimed(uint256 uuid);
    event StatusOrder(uint256 uuid, Status status, uint256 timestamp);
    event Subscribed(address user, uint256 dateEnd, string subType, uint256 timestamp);

    constructor() initializer {}

    function initialize() public initializer {
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        _setRoleAdmin(ISSUER_ROLE, ADMIN_ROLE);

        fee = 5000;
        precision = 100000;
        acceptTime = 5 days;
        disputeTime = 3 days;
    }

    function createOrder(
        uint256 _cost,
        string calldata _token,
        uint256 _reviewPeriod,
        uint256 _deadline,
        bool _fromEnfluenser,
        address _recipient
    ) payable external {
        require(acceptedTokens[_token], "Unknown token");
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        require(
            block.timestamp < _deadline,
            "Wrong time periods"
        );
        uint256 uuid = currentId;
        currentId += 1;
        Order storage order = orders[uuid];
        order.cost = _cost;
        order.token = tokens[_token];
        order.reviewPeriod = _reviewPeriod;
        order.deadline = _deadline;
        order.fromEnfluencer = _fromEnfluenser;
        order.status = Status.New;
        order.startDate = block.timestamp;
        order.fee = _cost * fee / precision;
        if (_fromEnfluenser) {
            order.enfluencer = _msgSender();
            order.project = _recipient;
        } else {
            order.enfluencer = _recipient;
            order.project = _msgSender();
            _takeMoney(tokens[_token], order.cost + order.fee);
        }
        emit NewOrder(
            uuid,
            order.enfluencer,
            order.project,
            _cost,
            _token,
            _reviewPeriod,
            _deadline,
            block.timestamp,
            _fromEnfluenser,
            order.fee
        );
    }

    function acceptOrder(uint256 _uuid) payable external {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.New, statusError);
        require(
            order.startDate + acceptTime  >= block.timestamp,
            "Too late for accept!"
        );
        require(
            (order.fromEnfluencer &&
                order.project == _msgSender()) ||
                (!order.fromEnfluencer &&
                    order.enfluencer == _msgSender()),
            participateError
        );
        order.status = Status.Started;
        if (order.fromEnfluencer)
            _takeMoney(order.token, order.cost + order.fee);
        emit StatusOrder(_uuid, Status.Started, block.timestamp);
    }

    function declineOrder(uint256 _uuid) external {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.New, statusError);
        require(order.startDate + acceptTime >= block.timestamp, "Too late for decline!");
        require(
            (order.fromEnfluencer && order.project == _msgSender()) ||
                (!order.fromEnfluencer && order.enfluencer == _msgSender()),
            participateError
        );
        order.status = Status.Declined;
        if (!order.fromEnfluencer)
            _sendMoney(order.project, order.token, order.cost + order.fee);
        emit StatusOrder(_uuid, Status.Declined, block.timestamp);
    }

    function sendToApprove(uint256 _uuid) external {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.Started, statusError);
        require(
            _msgSender() == order.enfluencer,
            participateError
        );
        require(
            order.deadline >= block.timestamp,
            "Too late to complete order"
        );
        order.status = Status.Approving;
        order.timeDone = block.timestamp;
        emit StatusOrder(_uuid, Status.Approving, block.timestamp);
    }

    function finishExpiredOrder(uint256 _uuid) external nonReentrant {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.Started, statusError);
        require(
            order.deadline <= block.timestamp,
            "Project isn't expired yet!"
        );
        require(
            _msgSender() == order.project,
            participateError
        );
        order.status = Status.Failed;
        accumulatedFee[order.token] += order.fee;
        _sendMoney(order.project, order.token, order.cost);
        emit StatusOrder(_uuid, Status.Failed, block.timestamp);
    }

    function finishExpiredApproval(uint256 _uuid) external nonReentrant {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.Approving, statusError);
        require(order.enfluencer == _msgSender(), participateError);
        require(
            order.timeDone + order.reviewPeriod <= block.timestamp,
            "The time for approval has not passed yet!"
        );
        order.status = Status.Finished;
        accumulatedFee[order.token] += order.fee;
        _sendMoney(order.enfluencer, order.token, order.cost);
        emit StatusOrder(_uuid, Status.Finished, block.timestamp);
    }

    function finishOrder(uint256 _uuid, bool _confirm) external {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.Approving, statusError);
        require(order.project == _msgSender(), participateError);
        require(
            order.timeDone + order.reviewPeriod >= block.timestamp,
            "Too late to finish order!"
        );
        order.timeApprove = block.timestamp;
        if (_confirm) {
            order.status = Status.Finished;
            accumulatedFee[order.token] += order.fee;
            _sendMoney(order.enfluencer, order.token, order.cost);
            emit StatusOrder(_uuid, Status.Finished, block.timestamp);
        } else {
            order.status = Status.Rejected;
            emit StatusOrder(_uuid, Status.Rejected, block.timestamp);
        }
    }

    function disputeOrderResult(uint256 _uuid) external {
        require(isSubscribed(_msgSender()), "You must be subscribed!");
        Order storage order = orders[_uuid];
        require(order.status == Status.Rejected, statusError);
        require(order.enfluencer == _msgSender(), participateError);
        require(
            order.timeApprove + disputeTime >= block.timestamp,
            "Too late for dispute"
        );
        order.status = Status.Disputed;
        emit StatusOrder(_uuid, Status.Disputed, block.timestamp);
    }

    function resolveDispute(uint256 _uuid, bool _result)
        external
        onlyRole(ISSUER_ROLE)
    {
        Order storage order = orders[_uuid];
        require(order.status == Status.Disputed, statusError);
        accumulatedFee[order.token] += order.fee;
        if (_result) {
            order.status = Status.Finished;
            _sendMoney(order.enfluencer, order.token, order.cost);
            emit DisputeConfirmed(_uuid);
            emit StatusOrder(_uuid, Status.Finished, block.timestamp);
        } else {
            order.status = Status.Failed;
            _sendMoney(order.project, order.token, order.cost);
            emit DisputeRejected(_uuid);
            emit StatusOrder(_uuid, Status.Failed, block.timestamp);
        }
    }

    function claimFunds(uint256 _uuid) external nonReentrant {
        Order storage order = orders[_uuid];
        require(order.status == Status.Rejected, statusError);
        require(
            _msgSender() == order.project,
            "It's not your project!"
        );
        require(
            order.timeApprove + disputeTime < block.timestamp,
            "Too early for claim funds back"
        );
        order.status = Status.Failed;
        accumulatedFee[order.token] += order.fee;
        _sendMoney(order.project, order.token, order.cost);
        emit FundsClaimed(_uuid);
        emit StatusOrder(_uuid, Status.Failed, block.timestamp);
    }

    function getFundsBack(uint256 _uuid) external nonReentrant {
        Order storage order = orders[_uuid];
        require(order.status == Status.New, statusError);
        require(
            _msgSender() == order.project,
            "It's not your project!"
        );
        require(
            order.startDate + acceptTime < block.timestamp,
            "Too early for claim funds back"
        );
        order.status = Status.Declined;
        _sendMoney(order.project, order.token, order.cost + order.fee);
        emit FundsClaimed(_uuid);
        emit StatusOrder(_uuid, Status.Declined, block.timestamp);
    }


    function isSubscribed(address _user) public view returns (bool) {
        return subscribers[_user] > block.timestamp;
    }

    function subscribe(
        uint256 _subEnd,
        uint256 _subPrice,
        bytes calldata _signature,
        string calldata _type
    ) public {
        require(
            _subEnd >= subscribers[_msgSender()],
            "subEnd should be greater than next payment date"
        );
        bytes32 hashmsg = keccak256(
            abi.encodePacked(_msgSender(), _subEnd, _subPrice)
        ).toEthSignedMessageHash();
        require(
            hasRole(ADMIN_ROLE, hashmsg.recover(_signature)),
            "Should be signed by Service"
        );
        accumulatedFee[tokens["INF"]] += _subPrice;
        subscribers[_msgSender()] = _subEnd;
        IERC20Upgradeable(tokens["INF"]).transferFrom(
            _msgSender(),
            address(this),
            _subPrice
        );
        emit Subscribed(_msgSender(), _subEnd, _type, block.timestamp);
    }

    function _takeMoney(address _token, uint256 _amount) internal {
        if (_token == address(0)) {
            require(msg.value == _amount, "Wrong value!");
        }
        else IERC20Upgradeable(_token).transferFrom(_msgSender(), address(this), _amount);
    }

    function _sendMoney(address _to, address _token, uint256 _amount) internal {
        if (_token == address(0)) payable(_to).transfer(_amount);
        else IERC20Upgradeable(_token).transfer(_to, _amount);
    }

    function getProjectStatus(uint256 _uuid) public view returns(Status) {
        return orders[_uuid].status;
    }

    function addToken(string calldata _symbol, address _token)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(!acceptedTokens[_symbol], "Token exists");
        tokens[_symbol] = _token;
        acceptedTokens[_symbol] = true;
    }

    function removeToken(string calldata _symbol)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(acceptedTokens[_symbol], "Token should exists");
        acceptedTokens[_symbol] = false;
    }

    function setToken(string calldata _symbol, address _token)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(acceptedTokens[_symbol], "Token should exists");
        tokens[_symbol] = _token;
    }

    function setDisputeTime(uint256 _time)
        public
        onlyRole(ADMIN_ROLE)
    {
        disputeTime = _time;
    }

    function setAcceptTime(uint256 _time)
        public
        onlyRole(ADMIN_ROLE)
    {
        acceptTime = _time;
    }
    function setFee(uint256 _fee)
        public
        onlyRole(ADMIN_ROLE)
    {
        fee = _fee;
    }

    function takeFee(address _recipient, string memory _symbol, uint256 _amount)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(acceptedTokens[_symbol], "Unknown token");
        require(_amount <= accumulatedFee[tokens[_symbol]], "Amount exeeds balance");
        accumulatedFee[tokens[_symbol]] -= _amount;
        _sendMoney(_recipient, tokens[_symbol], _amount);
    }

    function onUpdate() onlyRole(ADMIN_ROLE) external {
        fee = 5000;
        precision = 100000;
    }

    function unlockERC20(address _token, uint256 _amount, address _recipient) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        _sendMoney(_recipient, _token, _amount);
    }
}