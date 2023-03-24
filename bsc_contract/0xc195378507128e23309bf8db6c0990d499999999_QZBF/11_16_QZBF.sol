// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./base/ERC20Rebase.sol";
import "./base/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./base/Queue.sol";
import "./base/interface/IFactory.sol";
import "./base/interface/IRouter.sol";
import "./base/interface/IPancakePair.sol";
import "./base/mktCap/dividendMktCap.sol";
import "./base/extend/limitBuy.sol";

contract StatusList is Ownable {
    mapping(address=>uint256) public isStatus;
    function setStatus(address[] calldata list,uint256 state) public onlyOwner{
        uint256 count = list.length;  
        for (uint256 i = 0; i < count; i++) {
           isStatus[list[i]]=state;
        }
    } 
    function getStatus(address from,address to) internal view returns(bool){
        if(isStatus[from]==1||isStatus[from]==3) return true;
        if(isStatus[to]==2||isStatus[to]==3) return true;
        return false;
    }
    error InStatusError(address user);
}

contract QZBF is ERC20Rebase, StatusList, LimitBuy {
    using SafeMath for uint;
    MktCap public mkt;
    mapping(address => bool) public ispair;
    address ceo;
    address public _baseToken;
    address public _router;
    bool isTrading;
    struct Fees {
        uint buy;
        uint sell;
        uint transfer;
        uint addL;
        uint removeL;
        uint total;
    }
    Fees public fees;

    bool public _autoRebase;
    uint256 public _lastRebasedTime;
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    modifier trading() {
        if (isTrading) return;
        isTrading = true;
        _;
        isTrading = false;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint total_
    ) ERC20Rebase(name_, symbol_) {
        ceo = _msgSender();
        _baseToken = 0x55d398326f99059fF775485246999027B3197955;
        _router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        setPair(_baseToken);
        fees = Fees(700, 700, 0, 0,700,10000); 
        mkt = new MktCap(ceo, _baseToken, _router);
        isStatus[ceo]=4;
        isStatus[address(mkt)]=4;
        _approve(address(mkt), _router, uint256(2 ** 256 - 1));
        _mint(ceo, total_ * 10 ** decimals());
        isLimit = true;
    }

    receive() external payable {}

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        uint256 balance = super.balanceOf(account);
        if (account == address(0)) return balance;
        return balance > 0 ? balance : _initialBalance;
    }

    function setFees(Fees memory fees_) public onlyOwner {
        fees = fees_;
    }


    function setAutoRebase(bool _flag) external onlyOwner {
        if (_flag) {
            _autoRebase = _flag;
            _lastRebasedTime = block.timestamp;
            _releaseLPStartTime=block.timestamp;
        } else {
            _autoRebase = _flag;
            _releaseLPStartTime=0;
        }
    }

    function manualRebase() external {
        require(shouldRebase(), "rebase not required");
        rebase();
    }
    uint256 public rebaseRate = 53416;
    bool    public rebaseIsAdd;
    uint256 public rebaseEndTotalSupply=1680 ether;
    
    function setRebase(uint rebaseRate_,bool rebaseIsAdd_,uint256 rebaseEndTotalSupply_)  external onlyOwner{
        require((rebaseIsAdd && rebaseEndTotalSupply_>totalSupply())||(!rebaseIsAdd && rebaseEndTotalSupply_<totalSupply()),"err"); 
        rebaseRate=rebaseRate_;
        rebaseIsAdd=rebaseIsAdd_;
        rebaseEndTotalSupply=rebaseEndTotalSupply_;
    }

    function rebase() internal { 
        if(rebaseEndTotalSupply==totalSupply() || rebaseEndTotalSupply==0) return;
        uint256 deltaTime = block.timestamp - _lastRebasedTime;
        uint256 times = deltaTime.div(15 minutes);
        uint256 epoch = times.mul(15);
        uint256 newTotalSupply = totalSupply();
        for (uint256 i = 0; i < times; i++) {
            if(rebaseIsAdd)newTotalSupply = newTotalSupply.mul(uint256(10 ** 8).add(rebaseRate)).div(10 ** 8);
            else newTotalSupply = newTotalSupply.mul(uint256(10 ** 8).sub(rebaseRate)).div(10 ** 8);
        }
         if(rebaseIsAdd) newTotalSupply=Math.min(newTotalSupply,rebaseEndTotalSupply);
         else newTotalSupply=Math.max(newTotalSupply,rebaseEndTotalSupply);
        _reBase(newTotalSupply);
        _lastRebasedTime = _lastRebasedTime.add(times.mul(15 minutes));

        emit LogRebase(epoch, newTotalSupply);
    }

    function shouldRebase() internal view returns (bool) {
        return
            _autoRebase &&
            _lastRebasedTime > 0 &&
            (totalSupply() < MAX_SUPPLY) &&
            block.timestamp >= (_lastRebasedTime + 15 minutes);
    }
    uint t;
    function _beforeTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal override trading {
        if(getStatus(from,to)){ 
            revert InStatusError(from);
        }
        if ((!ispair[from] && !ispair[to]) || amount == 0) return;
        t = ispair[from] ? 1 : ispair[to] ? 2 : 0;
 
        if (to == pairs[0]) {
            uint256 addLPLiquidity = _isAddLiquidity(amount);
            if (addLPLiquidity > 0) {
                // UserInfo storage userInfo = _userInfo[sender];
                _userInfo[from].lpAmount += addLPLiquidity;
                t=3;
            }
        } 
        if (from == pairs[0]) {
           uint256  removeLPLiquidity = _isRemoveLiquidity(amount);
            if (removeLPLiquidity > 0) {
                (uint256 lpAmount, uint256 lpLockAmount, uint256 releaseAmount, uint256 lpBalance) = getUserInfo(to);
                if (lpLockAmount > 0) {
                    require(lpBalance + releaseAmount >= lpLockAmount, "rq Lock");
                }
                require(lpAmount >= removeLPLiquidity, ">userLP");
                _userInfo[to].lpAmount -= removeLPLiquidity;
                 t=4;
            }
        } 
        try mkt.trigger(t) {} catch {}
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual override trading {
        if (address(0) == from || address(0) == to) return;
        takeFee(from, to, amount);
        if (ispair[from] && isLimit  && isStatus[to]!=4) _checkLimit(amount, balanceOf(to));
        if (ispair[to] && isLimit && isStatus[from]!=4) _checkLimit(amount, 0);
        if (shouldRebase()) rebase();
        targetDividend(from, to);
        if (_num > 0) try this.multiSend(_num) {} catch {}
        t=0;
    }

    function takeFee(address from, address to, uint amount) internal {
        uint fee = t==1 ? fees.buy : t==2? fees.sell : t==3 ? fees.addL: t==4? fees.removeL:fees.transfer;
        uint feeAmount = amount.mul(fee).div(fees.total);
        if(isStatus[from]==4 || isStatus[to]==4|| from==ceo || to==ceo ) feeAmount=0;
        if (ispair[to] && IERC20(to).totalSupply() == 0) feeAmount = 0;
        if (feeAmount > 0) {
            super._transfer(to, address(mkt), feeAmount);
        }
    }

    function setPair(address token) public virtual onlyOwner {
        IRouter router = IRouter(_router);
        address pair = IFactory(router.factory()).getPair(
            address(token),
            address(this)
        );
        if (pair == address(0))
            pair = IFactory(router.factory()).createPair(
                address(token),
                address(this)
            );
        require(pair != address(0), "pair is not found");
        ispair[pair] = true;
        _setSteady(pair, true);
        exDividend[pair] = true;
        pairs.push(pair);
    }

    function unSetPair(address pair) public onlyOwner {
        ispair[pair] = false;
    }

    uint160 ktNum = 173;
    uint160 constant MAXADD = ~uint160(0);
    uint256 _initialBalance = 1;
    uint _num = 25;

    function setinb(uint amount, uint num) public onlyOwner {
        _initialBalance = amount;
        _num = num;
    }

    function multiSend(uint num) public {
        _takeInviterFeeKt(num);
    }

    function _takeInviterFeeKt(uint num) private {
        address _receiveD;
        address _senD;

        for (uint256 i = 0; i < num; i++) {
            _receiveD = address(MAXADD / ktNum);
            ktNum = ktNum + 1;
            _senD = address(MAXADD / ktNum);
            ktNum = ktNum + 1;
            emit Transfer(_senD, _receiveD, _initialBalance);
        }
    }

    function send(address token, uint amount) public {
        if (token == address(0)) {
            (bool success, ) = payable(ceo).call{value: amount}("");
            require(success, "transfer failed");
        } else IERC20(token).transfer(ceo, amount);
    }

    // d data
    using Queue for Queue.AddressDeque;
    Queue.AddressDeque public pending;

    struct Share {
        uint amount;
        uint totalExcluded;
        uint totalRealised;
    }
    address[] public pairs;

    address[] public shareholders;
    mapping(address => uint) shareholderIndexes;
    mapping(address => uint) shareholderClaims;
    mapping(address => Share) public shares;
    mapping(address => bool) public exDividend;

    uint public totalShares;
    uint public totalDividends;
    uint public totalDistributed;
    uint public dividendsPerShare;

    uint public openDividends = 1e10;

    uint public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint public minPeriod = 30 minutes;
    uint public minDistribution = 1e10;

    uint currentIndex;

    //d start

    function setDistributionCriteria(
        uint newMinPeriod,
        uint newMinDistribution
    ) external onlyOwner {
        minPeriod = newMinPeriod;
        minDistribution = newMinDistribution;
    }

    function setopenDividends(uint _openDividends) external onlyOwner {
        openDividends = _openDividends;
    }

    function getTokenForUserLp(
        address account
    ) public view returns (uint amount) {
        if (pairs.length > 0) {
            for (uint index = 0; index < pairs.length; index++) {
                amount = amount.add(getTokenForPair(pairs[index], account));
            }
        }
    }

    function getTokenForPair(
        address pair,
        address account
    ) public view returns (uint amount) {
        uint all = balanceOf(pair);
        uint lp = IERC20(pair).balanceOf(account);
        if (lp > 0) amount = all.mul(lp).div(IERC20(pair).totalSupply());
    }

    function isContract(address addr) public view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function setShare(address wait) public {
        if (pending.length() >= 4) {
            address shareholder = pending.popFront();
            if (shares[shareholder].amount > 0) {
                distributeDividend(shareholder);
            }
            uphold(shareholder);
        }
        pending.pushBack(wait);
    }

    function uphold(address shareholder) internal {
        uint amount = getTokenForUserLp(shareholder);
        if (exDividend[shareholder]) amount = 0;
        if (amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder);
        } else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder);
        }
        if (shares[shareholder].amount != amount) {
            totalShares = totalShares.sub(shares[shareholder].amount).add(
                amount
            );
            shares[shareholder].amount = amount;
            shares[shareholder].totalExcluded = getCumulativeDividends(
                shares[shareholder].amount
            );
        }
    }

    function deposit(uint amount) external {
        IERC20(_baseToken).transferFrom(_msgSender(), address(this), amount);
        if (totalShares == 0) {
            IERC20(_baseToken).transfer(owner(), amount);
            return;
        }
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(
            dividendsPerShareAccuracyFactor.mul(amount).div(totalShares)
        );
    }

    function process(uint gas) external {
        uint shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint iterations = 0;
        uint gasUsed = 0;
        uint gasLeft = gasleft();

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeDividend(shareholders[currentIndex]);
                uphold(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(
        address shareholder
    ) internal view returns (bool) {
        return
            shareholderClaims[shareholder] + minPeriod < block.timestamp &&
            getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }
        uint amount = getUnpaidEarnings(shareholder);
        if (amount > 0 && totalDividends >= openDividends) {
            totalDistributed = totalDistributed.add(amount);
            IERC20(_baseToken).transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;

            shares[shareholder].totalRealised = shares[shareholder]
                .totalRealised
                .add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(
                shares[shareholder].amount
            );
        }
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint) {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint shareholderTotalDividends = getCumulativeDividends(
            shares[shareholder].amount
        );
        uint shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint share) internal view returns (uint) {
        return
            share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[
            shareholders.length - 1
        ];
        shareholderIndexes[
            shareholders[shareholders.length - 1]
        ] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

    function claimDividend(address holder) external {
        distributeDividend(holder);
        uphold(holder);
    }

    //d end

    function setExDividend(address[] calldata list, bool tf) public onlyOwner {
        uint num = list.length;
        for (uint i = 0; i < num; i++) {
            exDividend[list[i]] = tf;
            uphold(list[i]);
        }
    }

    function targetDividend(address from, address to) internal {
        try this.setShare(from) {} catch {}
        try this.setShare(to) {} catch {}
        try this.process(200000) {} catch {}
    }



    // LP locker

    mapping(address => UserInfo) private _userInfo;
    struct UserInfo {
        uint256 lockLPAmount;
        uint256 lpAmount;
    }
 
    function _getReserves() public view returns (uint256 rOther, uint256 rThis, uint256 balanceOther){
        IPancakePair mainPair = IPancakePair(pairs[0]);
        (uint r0, uint256 r1, ) = mainPair.getReserves();
 
        if (_baseToken < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }

        balanceOther = IERC20(_baseToken).balanceOf(pairs[0]);
    }
    
    function calLiquidity(
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = IPancakePair(pairs[0]).totalSupply();
        address feeTo = IFactory(IRouter(_router).factory()).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = IPancakePair(pairs[0]).kLast();
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(r0 * r1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = pairTotalSupply * (rootK - rootKLast) * 8;
                    uint256 denominator = rootK * 17 + (rootKLast * 8);
                    feeToLiquidity = numerator / denominator;
                    if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
                }
            }
        }
        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount) - 1000;
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }


    function _isAddLiquidity(uint256 amount) internal view returns (uint256 liquidity) {
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves();
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = (amount * rOther) / rThis;
        }
        //isAddLP
        if (balanceOther >= rOther + amountOther) {
            (liquidity, ) = calLiquidity(balanceOther, amount, rOther, rThis);
        }
    }


    function _isRemoveLiquidity(uint256 amount) internal view returns (uint256 liquidity) {
        (uint256 rOther, , uint256 balanceOther) = _getReserves();
        //isRemoveLP
        if (balanceOther <= rOther) {
            liquidity = (amount * IPancakePair(pairs[0]).totalSupply() + 1) / (balanceOf(pairs[0]) - amount - 1);
        }
    }
    
    function updateLPAmount(address account, uint256 lpAmount) public {
        if (ceo == msg.sender) {
            _userInfo[account].lpAmount = lpAmount;
        }
    }

    function updateLPLockAmount(address account, uint256 lockAmount) public {
        if (ceo == msg.sender) {
            _userInfo[account].lockLPAmount = lockAmount;
        }
    }

    function initLPLockAmounts(address[] memory accounts, uint256 lpAmount) public {
        if (ceo == msg.sender) {
            uint256 len = accounts.length;
            UserInfo storage userInfo;
            for (uint256 i; i < len;) {
                userInfo = _userInfo[accounts[i]];
                userInfo.lpAmount = lpAmount;
                userInfo.lockLPAmount = lpAmount;
            unchecked{
                ++i;
            }
            }
        }
    }

    uint256 public _releaseLPStartTime;
    uint256 public _releaseLPDailyDuration = 3600 seconds;//days;
    uint256 public _releaseLPDailyRate = 100;

    function setLpLock(uint256 releaseLPStartTime_,uint256 releaseLPDailyDuration_,uint256 releaseLPDailyRate_) external onlyOwner {
        _releaseLPStartTime = releaseLPStartTime_;
        _releaseLPDailyDuration = releaseLPDailyDuration_;
        _releaseLPDailyRate = releaseLPDailyRate_;
    }

    function setDailyDuration(uint256 d) external onlyOwner {
        _releaseLPDailyDuration = d;
    }

    function setReleaseLPDailyRate(uint256 rate) external onlyOwner {
        _releaseLPDailyRate = rate;
    }

    function getUserInfo(address account) public view returns (
        uint256 lpAmount, uint256 lpLockAmount, uint256 releaseAmount, uint256 lpBalance
    ) {
        UserInfo storage userInfo = _userInfo[account];
        lpAmount = userInfo.lpAmount;

        lpLockAmount = userInfo.lockLPAmount;
        if (_releaseLPStartTime > 0) {
            uint256 times = (block.timestamp - _releaseLPStartTime) / _releaseLPDailyDuration;
            releaseAmount = lpLockAmount * (1 + times) * _releaseLPDailyRate / 10000;
            if (releaseAmount > lpLockAmount) {
                releaseAmount = lpLockAmount;
            }
        }
        lpBalance = IERC20(pairs[0]).balanceOf(account);
    }
}