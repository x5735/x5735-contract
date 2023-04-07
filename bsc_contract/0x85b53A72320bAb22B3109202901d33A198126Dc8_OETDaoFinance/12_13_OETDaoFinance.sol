// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interface/IPancakePair.sol";
import "./Rel.sol";
import "./library/Utility.sol";

contract OETDaoFinance is Ownable {
    using SafeERC20 for ERC20;
    using BitMaps for BitMaps.BitMap;
    using Address for address;

    event NewPool(uint256 indexed id, uint256 cap, uint64 start);
    event BuyPoints(
        address indexed user,
        uint256 amount,
        uint256 price,
        uint256 points
    );
    event NetAddPoints(
        address indexed user,
        address indexed buyer,
        uint256 tier,
        uint256 points
    );
    event Deposit(address indexed user, uint256 amount);
    event SwapPoints(
        address indexed user,
        uint256 amount,
        uint256 points,
        uint256 presentPoints
    );
    event SwapPoints2(
        address indexed user,
        uint256 amount,
        uint256 price,
        uint256 points
    );
    event StakeSubPoints(
        address indexed user,
        uint256 indexed poolId,
        uint256 indexed issue,
        uint256 points,
        uint256 luckyPoints
    );
    event NetSubPoints(
        address indexed user,
        address stakeUser,
        uint256 indexed poolId,
        uint256 indexed issue,
        uint256 tier,
        uint256 points,
        uint256 luckyPoints
    );
    event Stake(
        address indexed user,
        uint256 indexed poolId,
        uint256 indexed issue,
        uint256 amount
    );
    event Save(
        uint256 indexed poolId,
        uint128 indexed issueNo,
        address indexed safe,
        uint256 amount
    );
    event NewIssue(
        uint256 indexed poolId,
        uint128 indexed issueNo,
        uint256 issueCap,
        uint256 totalAmount
    );
    event Withdraw(address indexed user, uint256 amount, uint256 actualAmount);
    event WithdrawToken(
        address indexed user,
        uint256 amount,
        uint256 actualAmount
    );

    event WriteOff(address indexed user, uint256 amount, uint256 luckyPoint);

    event Checkout(
        address indexed buyer,
        uint256 indexed orderNo,
        address seller,
        uint256 amount,
        uint256 luckyPointAmount
    );
    event Confirm(
        address indexed buyer,
        uint256 indexed orderNo,
        address seller,
        uint256 amount,
        uint256 luckyPointAmount
    );
    event Refund(
        address indexed buyer,
        uint256 indexed orderNo,
        address seller,
        uint256 amount,
        uint256 luckyPointAmount
    );

    struct Pool {
        uint256 initCap;
        uint64 startTime;
        uint128 currIssue;
        bool blowUp;
        uint256 currCap;
        uint256 currIssueAmount;
        uint256 totalAmount;
    }
    struct Order {
        address buyer;
        address seller;
        uint64 status;
        uint256 amount;
        uint256 luckyPointAmount;
    }

    uint64 public constant ISSUE_PERIOD = 1 days;
    uint32 public constant ISSUE_PER_ROUND = 7;
    uint256 public constant ROUND_RATE = 25;
    uint256 public constant INTEREST_RATE = 98;
    uint256 public constant INTEREST_MARGIN_RATE = 932;
    uint256 public constant MIN_AMOUNT = 50 ether;

    Rel public rel;
    ERC20 public pointToken;
    IPancakePair public pair;
    ERC20 public usdtToken;
    Pool[] public pools;
    address public pja;
    address public pjb;
    address public pjc;
    address public pjd;
    address private adm;
    address public colSafeAddress;
    mapping(address => uint256) balancePerUser;
    mapping(address => uint256) pointsPerUser;
    mapping(address => uint256) luckyPointsPerUser;
    BitMaps.BitMap private firstPerIssue;
    mapping(address => mapping(uint256 => mapping(uint128 => uint256)))
        public amountPerUser;
    mapping(address => mapping(uint256 => uint256)) public stakingPerUser;
    mapping(address => mapping(uint256 => mapping(uint128 => uint256)))
        public netInterestPerUser;
    mapping(address => mapping(uint256 => uint128))
        public lastIssueUpdatePerUser;
    mapping(uint256 => uint128) public lastSaveIssuePerPool;
    mapping(uint256 => uint128) public lastMarginIssuePerPool;
    mapping(address => uint256) public tokenPerUser;
    mapping(address => uint256) public unwithdrawPerUser;
    BitMaps.BitMap private userSwaped;
    mapping(uint256 => Order) public orders;

    constructor(
        address r,
        address t,
        address pr,
        address a,
        address b,
        address c,
        address d,
        address ad,
        address s2
    ) {
        rel = Rel(r);
        rel.setPool(address(this));
        pointToken = ERC20(t);
        pair = IPancakePair(pr);
        usdtToken = ERC20(0x55d398326f99059fF775485246999027B3197955);
        pja = a;
        pjb = b;
        pjc = c;
        pjd = d;
        adm = ad;
        colSafeAddress = s2;
        uint256 cap = 40000 ether;
        Pool memory p = Pool(cap, 1680134400, 1, false, cap, 0, 0);
        pools.push(p);
        emit NewPool(0, cap, 1680134400);
    }

    function initPoints(
        address[] calldata addr,
        uint256[] calldata amount
    ) external onlyOwner {
        require(addr.length == amount.length);
        for (uint256 i = 0; i < addr.length; ++i) {
            address adr = addr[i];
            uint256 a = amount[i];
            pointsPerUser[adr] += a;
            emit BuyPoints(adr, 0, 0, a);
        }
    }

    function initBalance(
        address[] calldata addr,
        uint256[] calldata amount
    ) external onlyOwner {
        require(addr.length == amount.length);
        for (uint256 i = 0; i < addr.length; ++i) {
            address adr = addr[i];
            uint256 a = amount[i];
            balancePerUser[adr] += a;
            emit Deposit(adr, a);
        }
    }

    function newPool(uint256 cap, uint64 start) external {
        require(msg.sender == adm, "na");
        Pool memory p = Pool(cap, start, 1, false, cap, 0, 0);
        pools.push(p);
        emit NewPool(pools.length - 1, cap, start);
    }

    function buyPoints(uint256 amount) external {
        require(!msg.sender.isContract());
        require(rel.parents(msg.sender) != address(0), "nb");
        checkPoolBlowUp();
        require(pointToken.balanceOf(msg.sender) >= amount, "bne");
        uint256 a = amount / 10;
        pointToken.safeTransferFrom(msg.sender, pja, a);
        pointToken.safeTransferFrom(msg.sender, pjb, a * 5);
        uint256 b = a + a * 5;
        uint256 cost;
        a = a / 10;
        address p = msg.sender;
        for (uint256 i = 1; i <= 10; ++i) {
            p = rel.parents(p);
            if (p != address(0) && p != address(1)) {
                uint256 t = Utility.netPoints(i, a);
                tokenPerUser[p] += t;
                emit NetAddPoints(p, msg.sender, i, t);
                cost += t;
            } else {
                break;
            }
        }
        pointToken.safeTransferFrom(msg.sender, address(this), cost);
        if (amount > b + cost) {
            pointToken.safeTransferFrom(
                msg.sender,
                address(1),
                amount - b - cost
            );
        }
        uint256 level = rel.levelPerUser(msg.sender);
        if (level == 0) {
            rel.setLevel(msg.sender, 1);
            p = rel.parents(msg.sender);
            if (p != address(0) && p != address(1)) {
                rel.updateCountPerLevel(p, 0, 1);
                if (
                    rel.levelPerUser(p) == 1 &&
                    rel.countPerLevelPerUser(p, 1) >= 5
                ) {
                    rel.setLevel(p, 2);
                    p = rel.parents(p);
                    if (p != address(0) && p != address(1)) {
                        rel.updateCountPerLevel(p, 1, 2);
                        if (
                            rel.levelPerUser(p) == 2 &&
                            rel.countPerLevelPerUser(p, 2) >= 5
                        ) {
                            rel.setLevel(p, 3);
                            p = rel.parents(p);
                            if (p != address(0) && p != address(1)) {
                                rel.updateCountPerLevel(p, 2, 3);
                                if (
                                    rel.levelPerUser(p) == 3 &&
                                    rel.countPerLevelPerUser(p, 3) >= 3
                                ) {
                                    rel.setLevel(p, 4);
                                    p = rel.parents(p);
                                    if (p != address(0) && p != address(1)) {
                                        rel.updateCountPerLevel(p, 3, 4);
                                        if (
                                            rel.levelPerUser(p) == 4 &&
                                            rel.countPerLevelPerUser(p, 4) >= 3
                                        ) {
                                            rel.setLevel(p, 5);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 price = (reserve0 * 1 ether) / reserve1;
        uint256 points = (price * amount * 4) / 1 ether;
        pointsPerUser[msg.sender] += points;
        emit BuyPoints(msg.sender, amount, price, points);
        fullToSafe();
    }

    function deposit(uint256 amount) external {
        require(!msg.sender.isContract());
        require(rel.parents(msg.sender) != address(0), "nb");
        checkPoolBlowUp();
        usdtToken.safeTransferFrom(msg.sender, address(this), amount);
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(
            msg.sender,
            balance + amount,
            luckyPoints,
            unwithdraw
        );
        emit Deposit(msg.sender, amount);
        fullToSafe();
    }

    function amountByIssue(
        uint256 poolId,
        uint256 issueNo
    ) public view returns (uint256) {
        Pool memory pool = pools[poolId];
        uint256 m = issueNo / ISSUE_PER_ROUND;
        if (issueNo % ISSUE_PER_ROUND == 0 && m > 0) {
            --m;
        }
        uint256 amount = pool.initCap;
        for (uint256 i = 0; i < m; ++i) {
            amount += (amount * ROUND_RATE) / 100;
        }
        return amount;
    }

    function checkPoolBlowUp() private {
        uint256 issue = block.timestamp / ISSUE_PERIOD;
        if (!firstPerIssue.get(issue)) {
            for (uint256 i = 0; i < pools.length; ++i) {
                Pool memory p = pools[i];
                if (p.startTime <= block.timestamp && !p.blowUp) {
                    uint256 actualIssue = (block.timestamp - p.startTime) /
                        ISSUE_PERIOD +
                        1;
                    if (actualIssue > p.currIssue) {
                        pools[i].blowUp = true;
                    }
                }
            }
            firstPerIssue.set(issue);
        }
    }

    function checkLevelCap(
        address user,
        uint256[] memory stakingAmount,
        uint256 amount
    ) public view returns (bool result) {
        uint256 staking = amount;
        for (uint256 i = 0; i < stakingAmount.length; ++i) {
            staking += stakingAmount[i];
        }
        uint256 level = rel.levelPerUser(user);
        result = Utility.checkLevelCap(level, staking);
    }

    function calInterest(uint256 amount) private pure returns (uint256) {
        return (amount * INTEREST_RATE) / 1000;
    }

    function calBlowUpFirst(uint256 amount) private pure returns (uint256) {
        return (amount * 7) / 10;
    }

    function calBlowUpFirstLucky(
        uint256 amount
    ) private pure returns (uint256) {
        return (amount * 12) / 10;
    }

    function blowUpCal(
        address user,
        uint256 i,
        Pool memory p
    ) private view returns (uint256 sum, uint256 lucky, uint256 netInterest) {
        uint256 last4sum;
        uint256 last4total = p.currIssueAmount;
        for (uint256 k = 0; k <= 7 && p.currIssue > k; ++k) {
            if (k <= 3) {
                sum += amountPerUser[user][i][uint128(p.currIssue - k)];
                last4sum += amountPerUser[user][i][uint128(p.currIssue - k)];
                if (k != 0) {
                    last4total += amountByIssue(i, p.currIssue - k);
                }
            } else if (k == 4) {
                sum += amountPerUser[user][i][uint128(p.currIssue - k)];
            } else {
                sum += calBlowUpFirst(
                    amountPerUser[user][i][uint128(p.currIssue - k)]
                );
                lucky += calBlowUpFirstLucky(
                    amountPerUser[user][i][uint128(p.currIssue - k)]
                );
            }
        }
        if (last4total > 0) {
            lucky +=
                (last4sum * p.totalAmount * INTEREST_RATE) /
                1000 /
                4 /
                last4total;
        }
        if (p.currIssue > 8) {
            for (
                uint256 j = lastIssueUpdatePerUser[user][i] + 1;
                j <= p.currIssue - 8;
                ++j
            ) {
                uint256 sa = amountPerUser[user][i][uint128(j)];
                sum += sa;
                sum += calInterest(sa);
                sum += netInterestPerUser[user][i][uint128(j)];
                netInterest += netInterestPerUser[user][i][uint128(j)];
            }
        }
    }

    function userBalance(
        address user
    )
        public
        view
        returns (
            uint256 balance,
            uint256 points,
            uint256 luckyPoints,
            uint256 stakingAmount,
            uint256 unwithdraw
        )
    {
        for (uint256 i = 0; i < pools.length; ++i) {
            Pool memory p = pools[i];
            if (block.timestamp < p.startTime) {
                continue;
            }
            uint128 actualIssue = uint128(
                (uint64(block.timestamp) - p.startTime) / ISSUE_PERIOD + 1
            );
            bool blowUp = p.blowUp;
            if (p.startTime <= block.timestamp && !blowUp) {
                if (actualIssue > p.currIssue) {
                    blowUp = true;
                }
            }
            if (blowUp && lastIssueUpdatePerUser[user][i] < p.currIssue) {
                (
                    uint256 sum1,
                    uint256 lucky1,
                    uint256 netInterest1
                ) = blowUpCal(user, i, p);
                balance += sum1;
                luckyPoints += lucky1;
                unwithdraw += netInterest1;
            } else {
                if (
                    actualIssue > 8 &&
                    lastIssueUpdatePerUser[user][i] + 1 <= actualIssue - 8
                ) {
                    uint256 sa;

                    for (
                        uint256 j = lastIssueUpdatePerUser[user][i] + 1;
                        j <= actualIssue - 8;
                        ++j
                    ) {
                        uint256 t = amountPerUser[user][i][uint128(j)];
                        sa += t;
                        balance += t;
                        balance += calInterest(t);
                        balance += netInterestPerUser[user][i][uint128(j)];
                        unwithdraw += netInterestPerUser[user][i][uint128(j)];
                    }
                    stakingAmount += stakingPerUser[user][i] - sa;
                } else {
                    stakingAmount += stakingPerUser[user][i];
                }
            }
        }
        balance += balancePerUser[user];
        points = pointsPerUser[user];
        luckyPoints += luckyPointsPerUser[user];
        unwithdraw += unwithdrawPerUser[user];
    }

    function calBalance(
        address user
    )
        private
        view
        returns (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        )
    {
        lastUpdate = new uint128[](pools.length);
        stakingAmount = new uint256[](pools.length);
        for (uint256 i = 0; i < pools.length; ++i) {
            Pool memory p = pools[i];
            if (block.timestamp < p.startTime) {
                continue;
            }
            uint128 actualIssue = uint128(
                (uint64(block.timestamp) - p.startTime) / ISSUE_PERIOD + 1
            );
            if (p.blowUp && lastIssueUpdatePerUser[user][i] < p.currIssue) {
                (
                    uint256 sum1,
                    uint256 lucky1,
                    uint256 netInterest1
                ) = blowUpCal(user, i, p);
                balance += sum1;
                luckyPoints += lucky1;
                unwithdraw += netInterest1;
                stakingAmount[i] = 0;
                lastUpdate[i] = p.currIssue;
            } else {
                if (
                    actualIssue > 8 &&
                    lastIssueUpdatePerUser[user][i] + 1 <= actualIssue - 8
                ) {
                    uint256 sa;

                    for (
                        uint256 j = lastIssueUpdatePerUser[user][i] + 1;
                        j <= actualIssue - 8;
                        ++j
                    ) {
                        uint256 t = amountPerUser[user][i][uint128(j)];
                        sa += t;
                        balance += t;
                        balance += calInterest(t);
                        balance += netInterestPerUser[user][i][uint128(j)];
                        unwithdraw += netInterestPerUser[user][i][uint128(j)];
                        lastUpdate[i] = uint128(j);
                    }
                    stakingAmount[i] = stakingPerUser[user][i] - sa;
                } else {
                    stakingAmount[i] = stakingPerUser[user][i];
                }
            }
        }
        balance += balancePerUser[user];
        luckyPoints += luckyPointsPerUser[user];
        unwithdraw += unwithdrawPerUser[user];
    }

    function stake(uint256 poolId, uint256 amount) external {
        require(!msg.sender.isContract());
        checkPoolBlowUp();
        require(poolId < pools.length, "ide");
        Pool storage pool = pools[poolId];
        require(pool.startTime <= block.timestamp && !pool.blowUp, "un");
        uint256 rest = pool.currCap - pool.currIssueAmount;
        require(amount > 0 && amount <= rest, "aes");
        if (rest < MIN_AMOUNT) {
            require(rest == amount, "ae");
        } else {
            require(amount % MIN_AMOUNT == 0, "50x");
        }
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        require(balance >= amount, "bne");
        uint256 needPoints = (amount * INTEREST_RATE) / 1000;
        require(pointsPerUser[msg.sender] + luckyPoints >= needPoints, "pne");
        require(checkLevelCap(msg.sender, stakingAmount, amount), "elc");
        for (uint256 i = 0; i < stakingAmount.length; ++i) {
            stakingPerUser[msg.sender][i] = stakingAmount[i];
        }
        if (pointsPerUser[msg.sender] >= needPoints) {
            pointsPerUser[msg.sender] -= needPoints;
            luckyPointsPerUser[msg.sender] = luckyPoints;
            emit StakeSubPoints(
                msg.sender,
                poolId,
                pool.currIssue,
                needPoints,
                0
            );
        } else {
            emit StakeSubPoints(
                msg.sender,
                poolId,
                pool.currIssue,
                pointsPerUser[msg.sender],
                needPoints - pointsPerUser[msg.sender]
            );
            luckyPointsPerUser[msg.sender] =
                luckyPoints -
                (needPoints - pointsPerUser[msg.sender]);
            pointsPerUser[msg.sender] = 0;
        }

        amountPerUser[msg.sender][poolId][pool.currIssue] += amount;
        balancePerUser[msg.sender] = balance - amount;
        stakingPerUser[msg.sender][poolId] += amount;
        for (uint256 i = 0; i < lastUpdate.length; ++i) {
            if (
                lastUpdate[i] > 0 &&
                lastIssueUpdatePerUser[msg.sender][i] != lastUpdate[i]
            ) {
                lastIssueUpdatePerUser[msg.sender][i] = lastUpdate[i];
            }
        }
        emit Stake(msg.sender, poolId, pool.currIssue, amount);
        if (unwithdraw >= amount) {
            unwithdrawPerUser[msg.sender] = unwithdraw - amount;
        } else {
            unwithdrawPerUser[msg.sender] = 0;
        }

        subNet(needPoints, poolId, pool);

        pool.currIssueAmount += amount;
        pool.totalAmount += amount;
        fullToSafe();
        if (pool.currIssueAmount == pool.currCap) {
            pool.currIssue++;
            if (pool.currIssue % 7 == 1) {
                pool.currCap += (pool.currCap * 25) / 100;
            }
            pool.currIssueAmount = 0;
            emit NewIssue(
                poolId,
                pool.currIssue,
                pool.currCap,
                pool.totalAmount
            );
        }
    }

    function subNet(
        uint256 needPoints,
        uint256 poolId,
        Pool memory pool
    ) private {
        address p = rel.parents(msg.sender);
        for (
            uint256 i = 1;
            i <= 10 && p != address(0) && p != address(1);
            ++i
        ) {
            uint256 level = rel.levelPerUser(p);
            uint256 np;
            if (level == 0) {
                p = rel.parents(p);
                continue;
            } else if (level == 1) {
                if (i == 1) {
                    np = (needPoints * 15) / 100;
                } else if (i == 2) {
                    np = (needPoints * 5) / 100;
                } else {
                    p = rel.parents(p);
                    continue;
                }
            } else if (level == 2) {
                if (i == 1) {
                    np = (needPoints * 15) / 100;
                } else if (i >= 2 && i <= 4) {
                    np = (needPoints * 5) / 100;
                } else {
                    p = rel.parents(p);
                    continue;
                }
            } else if (level == 3) {
                if (i == 1) {
                    np = (needPoints * 15) / 100;
                } else if (i >= 2 && i <= 6) {
                    np = (needPoints * 5) / 100;
                } else {
                    p = rel.parents(p);
                    continue;
                }
            } else if (level == 4) {
                if (i == 1) {
                    np = (needPoints * 15) / 100;
                } else if (i >= 2 && i <= 8) {
                    np = (needPoints * 5) / 100;
                } else {
                    p = rel.parents(p);
                    continue;
                }
            } else if (level == 5) {
                if (i == 1) {
                    np = (needPoints * 15) / 100;
                } else if (i >= 2 && i <= 10) {
                    np = (needPoints * 5) / 100;
                } else {
                    p = rel.parents(p);
                    continue;
                }
            }
            (
                uint256 balance1,
                uint256 luckyPoints1,
                uint256[] memory stakingAmount1,
                uint128[] memory lastUpdate1,
                uint256 unwithdraw1
            ) = calBalance(p);
            balancePerUser[p] = balance1;
            updateLast(p, stakingAmount1, lastUpdate1);
            unwithdrawPerUser[p] = unwithdraw1;
            uint256 ap = pointsPerUser[p] + luckyPoints1 >= np
                ? np
                : pointsPerUser[p] + luckyPoints1;
            if (pointsPerUser[p] >= ap) {
                pointsPerUser[p] -= ap;
                luckyPointsPerUser[p] = luckyPoints1;
                emit NetSubPoints(
                    p,
                    msg.sender,
                    poolId,
                    pool.currIssue,
                    i,
                    ap,
                    0
                );
            } else {
                uint256 d = pointsPerUser[p];
                uint256 c = ap - d;
                emit NetSubPoints(
                    p,
                    msg.sender,
                    poolId,
                    pool.currIssue,
                    i,
                    d,
                    c
                );
                luckyPointsPerUser[p] = luckyPoints1 - c;
                pointsPerUser[p] = 0;
            }
            netInterestPerUser[p][poolId][pool.currIssue] += ap;
            p = rel.parents(p);
        }
    }

    function swapPoints(uint256 amount) external {
        require(rel.parents(msg.sender) != address(0), "nb");
        bool al = userSwaped.get(uint256(uint160(msg.sender)));
        uint256 presentPoints;
        if (!al) {
            require(amount >= 10 ether, "min");
            presentPoints = 40 ether;
            userSwaped.set(uint256(uint160(msg.sender)));
        }
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        require(balance >= amount, "bne");
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(msg.sender, balance - amount, luckyPoints, 0);
        pointsPerUser[msg.sender] += amount * 4 + presentPoints;
        if (unwithdraw >= amount) {
            unwithdrawPerUser[msg.sender] = unwithdraw - amount;
        } else {
            unwithdrawPerUser[msg.sender] = 0;
        }
        emit SwapPoints(msg.sender, amount, amount * 4, presentPoints);
        fullToSafe();
    }

    function swapPoints2(uint256 amount) external {
        require(rel.parents(msg.sender) != address(0), "nb");
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        require(tokenPerUser[msg.sender] >= amount, "bne");
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(msg.sender, balance, luckyPoints, unwithdraw);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 price = (reserve0 * 1 ether) / reserve1;
        uint256 points = (price * amount * 4) / 1 ether;
        tokenPerUser[msg.sender] -= amount;
        pointsPerUser[msg.sender] += points;
        emit SwapPoints2(msg.sender, amount, price, points);
        fullToSafe();
    }

    function withdraw(uint256 amount) external {
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        require(balance >= amount, "bne");
        require(balance - amount >= unwithdraw, "ea");
        updateLast(msg.sender, stakingAmount, lastUpdate);
        uint256 actualAmount = amount - amount / 100;
        updateBalanceLuckyPoints(
            msg.sender,
            balance - amount,
            luckyPoints,
            unwithdraw
        );
        usdtToken.safeTransfer(msg.sender, actualAmount);
        usdtToken.safeTransfer(pjc, amount / 100);
        emit Withdraw(msg.sender, amount, actualAmount);
        fullToSafe();
    }

    function withdrawToken(uint256 amount) external {
        require(rel.parents(msg.sender) != address(0), "nb");
        checkPoolBlowUp();
        require(tokenPerUser[msg.sender] >= amount, "bne");
        uint256 actualAmount = amount - amount / 100;
        pointToken.safeTransfer(msg.sender, actualAmount);
        pointToken.safeTransfer(pjc, amount / 100);
        tokenPerUser[msg.sender] -= amount;
        emit WithdrawToken(msg.sender, amount, actualAmount);
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(msg.sender, balance, luckyPoints, unwithdraw);
        fullToSafe();
    }

    function fullToSafe() private {
        for (uint256 poolId = 0; poolId < pools.length; ++poolId) {
            Pool memory pool = pools[poolId];
            if (block.timestamp < pool.startTime) {
                continue;
            }
            uint128 actualIssue = uint128(
                (uint64(block.timestamp) - pool.startTime) / ISSUE_PERIOD + 1
            );

            uint256 last = (actualIssue >= pool.currIssue &&
                pool.currCap > pool.currIssueAmount)
                ? pool.currIssue - 1
                : actualIssue;
            for (uint256 i = lastSaveIssuePerPool[poolId] + 1; i <= last; ++i) {
                uint256 a = amountByIssue(poolId, i);
                if (i > ISSUE_PER_ROUND) {
                    a -= amountByIssue(poolId, i - ISSUE_PER_ROUND);
                }
                usdtToken.safeTransfer(colSafeAddress, a);
                lastSaveIssuePerPool[poolId] = uint128(i);
                emit Save(poolId, uint128(i), colSafeAddress, a);
            }
            uint256 c = actualIssue < pool.currIssue
                ? actualIssue
                : pool.currIssue;
            if (c >= 9) {
                for (
                    uint256 i = lastMarginIssuePerPool[poolId] + 1;
                    i <= c - 8;
                    ++i
                ) {
                    uint256 a = (amountByIssue(poolId, i) *
                        INTEREST_MARGIN_RATE) / 10000;
                    usdtToken.safeTransfer(pjd, a);
                    lastMarginIssuePerPool[poolId] = uint128(i);
                    emit Save(poolId, uint128(i), pjd, a);
                }
            }
        }
    }

    function poolsInfo()
        external
        view
        returns (Pool[] memory ps, uint256[] memory actualIssues)
    {
        ps = new Pool[](pools.length);
        actualIssues = new uint256[](pools.length);
        for (uint256 i = 0; i < pools.length; ++i) {
            ps[i] = pools[i];
            if (ps[i].startTime <= block.timestamp) {
                uint256 actualIssue = (block.timestamp - ps[i].startTime) /
                    ISSUE_PERIOD +
                    1;
                actualIssues[i] = actualIssue;
                if (actualIssue > ps[i].currIssue) {
                    ps[i].blowUp = true;
                }
            }
        }
    }

    function updateLast(
        address user,
        uint256[] memory stakingAmount,
        uint128[] memory lastUpdate
    ) private {
        for (uint256 i = 0; i < stakingAmount.length; ++i) {
            stakingPerUser[user][i] = stakingAmount[i];
        }
        for (uint256 i = 0; i < lastUpdate.length; ++i) {
            if (
                lastUpdate[i] > 0 &&
                lastIssueUpdatePerUser[user][i] != lastUpdate[i]
            ) {
                lastIssueUpdatePerUser[user][i] = lastUpdate[i];
            }
        }
    }

    function checkout(
        uint256 orderNo,
        address seller,
        uint256 amount
    ) external {
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        uint256 luckyPointAmount = amount * 4;
        require(luckyPoints >= luckyPointAmount, "ne");
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(
            msg.sender,
            balance,
            luckyPoints - luckyPointAmount,
            unwithdraw
        );
        require(orders[orderNo].buyer == address(0), "oe");
        orders[orderNo] = Order(
            msg.sender,
            seller,
            0,
            amount,
            luckyPointAmount
        );
        emit Checkout(msg.sender, orderNo, seller, amount, luckyPointAmount);
    }

    function confirm(uint256 orderNo) external {
        Order memory order = orders[orderNo];
        require(order.buyer == msg.sender, "obe");
        require(order.status == 0, "se");
        orders[orderNo].status = 1;
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(order.seller);
        updateLast(order.seller, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(
            order.seller,
            balance,
            luckyPoints + order.luckyPointAmount,
            unwithdraw
        );
        emit Confirm(
            msg.sender,
            orderNo,
            order.seller,
            order.amount,
            order.luckyPointAmount
        );
    }

    function updateBalanceLuckyPoints(
        address user,
        uint256 balance,
        uint256 luckyPoints,
        uint256 unwithdraw
    ) private {
        luckyPointsPerUser[user] = luckyPoints;
        balancePerUser[user] = balance;
        unwithdrawPerUser[user] = unwithdraw;
    }

    function refund(uint256 orderNo) external {
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        Order memory order = orders[orderNo];
        require(order.seller == msg.sender, "se");
        require(order.status == 1, "se");
        require(luckyPoints >= order.luckyPointAmount, "ne");
        orders[orderNo].status = 2;
        updateLast(order.seller, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(
            order.seller,
            balance,
            luckyPoints - order.luckyPointAmount,
            unwithdraw
        );
        (
            uint256 balance1,
            uint256 luckyPoints1,
            uint256[] memory stakingAmount1,
            uint128[] memory lastUpdate1,
            uint256 unwithdraw1
        ) = calBalance(order.buyer);
        updateLast(order.buyer, stakingAmount1, lastUpdate1);
        updateBalanceLuckyPoints(
            order.buyer,
            balance1,
            luckyPoints1 + order.luckyPointAmount,
            unwithdraw1
        );
        emit Refund(
            msg.sender,
            orderNo,
            order.seller,
            order.amount,
            order.luckyPointAmount
        );
    }

    function writeOff(uint256 amount) external {
        checkPoolBlowUp();
        (
            uint256 balance,
            uint256 luckyPoints,
            uint256[] memory stakingAmount,
            uint128[] memory lastUpdate,
            uint256 unwithdraw
        ) = calBalance(msg.sender);
        require(luckyPoints >= amount, "ne");
        updateLast(msg.sender, stakingAmount, lastUpdate);
        updateBalanceLuckyPoints(
            msg.sender,
            balance,
            luckyPoints - amount,
            unwithdraw
        );
        emit WriteOff(msg.sender, amount, luckyPoints - amount);
    }
}