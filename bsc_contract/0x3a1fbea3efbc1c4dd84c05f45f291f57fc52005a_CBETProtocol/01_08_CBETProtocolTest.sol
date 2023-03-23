// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./Address.sol";
import "./Ownable.sol";
import "./IERC20Metadata.sol";
import "./SwapInterface.sol";
import "./IAToken.sol";
import "./IERC20.sol";

contract CBETProtocol is Ownable, IERC20Metadata {
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MAX_UINT256 = type(uint256).max;
    uint256 private constant MAX_SUPPLY = 8800000000 * 10 ** 18;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _trueTotalSupply;

    string private _name = "OOKC";
    string private _symbol = "OOKC";

    uint256 private _decimals = 18;

    address public uniswapV2RouterAddress;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2PairBNB;
    address public uniswapV2PairUSDT;
    address public usdt;

    mapping(address => bool) private excluded;
    mapping(address => bool) private exceptionAddress;
    address[] private exceptionAddressList;

    uint256 private startTime = 1680153331;

    uint256 private TOTAL_GONS;
    uint256 public _lastRebasedTime;
    uint256 private _gonsPerFragment;
    uint256 public pairBalance;
    uint256 public rebaseRate = 5208;

    IAToken private aTokenContract;
    IERC20 private IUsdt;
    IUniswapV2Pair private usdtPair;

    // Minimum balance
    uint256 minBalance = 88 * (10 ** 10);
    // 关联token的最低留存数量
    uint256 minSenderBalance = 1 * (10 ** 18);

    // 当前增发次数
    uint256 currentIssueCount = 0;
    // 接受增发的地址
    address issueAddress;
    uint256 firstIssueTime = 1679569200;

    // 买入交易的结构体
    struct TransferInfo {
        uint256 timestamp;
        uint256 amount;
    }
    // 买入交易记录
    mapping(address => TransferInfo[]) public payTransfers;

    bool lock;
    modifier swapLock() {
        require(!lock, "CBETProtocol: swap locked!");
        lock = true;
        _;
        lock = false;
    }

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    constructor(uint256 _initSupply, address _usdt, address _uniswapV2RouterAddress,address _iAToken,address _issueAddress) {
        require(_usdt != address(0), "CBETProtocol: usdt address is 0!");
        require(_uniswapV2RouterAddress != address(0), "CBETProtocol: router address is 0");

        _totalSupply = _initSupply * 10 ** _decimals;
        _trueTotalSupply = _totalSupply;
        TOTAL_GONS = MAX_UINT256 / 1e10 - (MAX_UINT256 / 1e10 % _totalSupply);
        _balances[owner()] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        usdt = _usdt;
        IUsdt = IERC20(usdt);
        uniswapV2RouterAddress = _uniswapV2RouterAddress;

        uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        uniswapV2PairBNB = IUniswapV2Factory(uniswapV2Router.factory())
        .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2PairUSDT = IUniswapV2Factory(uniswapV2Router.factory())
        .createPair(address(this), usdt);

        usdtPair = IUniswapV2Pair(uniswapV2PairUSDT);

        excluded[owner()] = true;
        excluded[address(this)] = true;
        excluded[uniswapV2RouterAddress] = true;

        aTokenContract = IAToken(_iAToken);

        issueAddress = _issueAddress;
        excluded[_issueAddress] = true;
        setExceptionAddress(_issueAddress,true);

        emit Transfer(address(0), owner(), _totalSupply);
    }

    function setLock(bool newLock) public onlyOwner {
        lock = newLock;
    }

    function setStartTime(uint256 _startTime) public onlyOwner {
        startTime = _startTime;
        if (_lastRebasedTime == 0) {
            _lastRebasedTime = _startTime;
        }
    }

    function setExcluded(address _addr, bool _state) public onlyOwner {
        excluded[_addr] = _state;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _trueTotalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (account == address(uniswapV2PairUSDT)){
            return pairBalance;
        }else if(isExceptionAddress(account)){
            return _balances[account];
        }else{
            return _balances[account] / _gonsPerFragment;
        }
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "CBETProtocol: decreased allowance below zero");

        _approve(owner, spender, currentAllowance - subtractedValue);

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "CBETProtocol: transfer from the zero address");
        require(to != address(0), "CBETProtocol: transfer to the zero address");

        // 是否允许交易所买入卖出
        _tradeControl(from, to);

        uint256 fromBalance;
        // 转账的时候，判断是否是交易所或例外地址，执行不同逻辑
        if (from == address(uniswapV2PairUSDT)) {
            fromBalance = pairBalance;
            // 3年限购策略
            if(_lastRebasedTime > 0 && block.timestamp < (startTime + 6 hours)){
                // 24小时购买交易金额是否超过98USDT
                require(get24HourTransfers(to) + getPrice(usdt,amount) > (98 * 10 ** _decimals), "Exceeding the purchase limit");
                // 本次交易写入钱包地址的买入交易记录
                uint256 currentTime = block.timestamp;
                TransferInfo memory newTransfer = TransferInfo(currentTime, getPrice(usdt,amount));
                payTransfers[to].push(newTransfer);
            }
        }else if(isExceptionAddress(from)){
            fromBalance = _balances[from];
        } else {
            fromBalance = _balances[from] / _gonsPerFragment;
            // 钱包必须保留0.00000088枚
            require(fromBalance - amount >= minBalance, "Insufficient balance after transfer");
            // 关联token必须有1枚
            require(aTokenContract.balanceOf(from) >= minSenderBalance, "Insufficient balance after transfer");
        }
        require(fromBalance >= amount, "CBETProtocol: transfer amount exceeds balance");

        _rebase(from);

        uint256 finalAmount = _fee(from, to, amount);

        _basicTransfer(from, to, finalAmount);
    }

    // 是否是例外地址
    function isExceptionAddress(address _addr) public view returns(bool){
        return exceptionAddress[_addr];
    }

    // 设置例外地址
    function setExceptionAddress(address _addr,bool _newState) public onlyOwner{
        exceptionAddress[_addr] = _newState;
        exceptionAddressList.push(_addr);
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) private {
        // 转账金额乘以涨币系数
        uint256 gonAmount = amount * _gonsPerFragment;
        // 交易所、例外地址不需要系数计算
        if (from == address(uniswapV2PairUSDT)){
            pairBalance = pairBalance - amount;
        }else if(isExceptionAddress(from)){
            _balances[from] = _balances[from] - amount;
        }else{
            _balances[from] = _balances[from] - gonAmount;
        }

        if (to == address(uniswapV2PairUSDT)){
            pairBalance = pairBalance + amount;
        }else if(isExceptionAddress(to)){
            _balances[to] = _balances[to] + amount;
        }else{
            _balances[to] = _balances[to] + gonAmount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "CBETProtocol: approve from the zero address");
        require(spender != address(0), "CBETProtocol: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "CBETProtocol: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function _rebase(address from) private {
        // 小于总发行量、不是交易所买入、不是例外地址、没有锁、已经开始涨币了、距离上次涨币超过15分钟、涨币还没超过3年
        if (
            _trueTotalSupply < MAX_SUPPLY &&
            from != address(uniswapV2PairUSDT)  &&
            !isExceptionAddress(from) &&
            !lock &&
            _lastRebasedTime > 0 &&
            block.timestamp >= (_lastRebasedTime + 15 minutes)
        ) {
            uint256 deltaTime = block.timestamp - _lastRebasedTime;
            uint256 times = deltaTime / (15 minutes);
            uint256 epoch = times * 15;

            // 涨币的时候,排除例外地址的币
            uint exceptionAddressListLength = exceptionAddressList.length;
            uint256 totalException;
            for (uint256 p = 0; p < exceptionAddressListLength; p++ ) {
                totalException = totalException + balanceOf(exceptionAddressList[p]);
            }
            _trueTotalSupply = _trueTotalSupply - totalException;

            for (uint256 i = 0; i < times; i++) {
                _totalSupply = _totalSupply
                * (10 ** 8 + rebaseRate)
                / (10 ** 8);

                _trueTotalSupply = _trueTotalSupply
                * (10 ** 8 + rebaseRate)
                / (10 ** 8);
            }

            //涨币完成后，把例外地址的币加回去
            _trueTotalSupply = _trueTotalSupply + totalException;

            _gonsPerFragment = TOTAL_GONS / _totalSupply;
            _lastRebasedTime = _lastRebasedTime + times * 15 minutes;

            emit LogRebase(epoch, _trueTotalSupply);
        }
    }

    function _tradeControl(address from, address to) view private {
        // 必须在管理员启用交易后才可以进行交易，否则只有白名单可以交易
        if (
            from == address(uniswapV2PairBNB) ||
            to == address(uniswapV2PairBNB) ||
            from == address(uniswapV2PairUSDT) ||
            to == address(uniswapV2PairUSDT)
        ) {
            address addr = (from == address(uniswapV2PairBNB) || from == address(uniswapV2PairUSDT)) ? to : from;
            if (excluded[addr]) {
                return;
            }

            if (startTime > block.timestamp) {
                revert("CBETProtocol: trade not started");
            }
        }
    }

    function _fee(address from, address to, uint256 amount) private returns (uint256) {
        // 白名单例外
        if (excluded[from]) {
            return amount;
        }
        // 千分之五分出去
        uint256 payFee = amount * 50 / 1000;
        // 如果是买入
        if (from == address(uniswapV2PairUSDT)){
            // 每个地址1%
            uint256 allFee = amount * 10 / 1000;

            for (uint256 i = 0; i < 5; i++) {
                // 获取邀请人
                address nowAddress = aTokenContract.getReferrer(to);
                // 如果没有邀请人，销毁
                if (nowAddress == address(0)) {
                    _basicTransfer(from, DEAD, allFee);
                    break;
                }

                // 获取地址是否加池超过18.8USDT，如果小于18.8USDT，就销毁了，不发放. 钱包持有LP/总发行LP*LP持有USDT(钱包持有LP*LP持有USDT/总发行LP)
                if (usdtPair.balanceOf(nowAddress) * IUsdt.balanceOf(address(uniswapV2PairUSDT)) / usdtPair.totalSupply() < (98 * 10 ** (_decimals - 1))) {
                    _basicTransfer(from, DEAD, allFee);
                    break;
                }
                // 大于18.8USDT，正常发放
                _basicTransfer(from, nowAddress, allFee);
            }

        // 如果是卖出
        } else if (to == address(uniswapV2PairUSDT)){
            // 分别是1% 1% 1.5% 1.5%
            uint256[] memory rewardPercentages = new uint256[](4);
            rewardPercentages[0] = amount * 10 / 1000;
            rewardPercentages[1] = amount * 10 / 1000;
            rewardPercentages[2] = amount * 15 / 1000;
            rewardPercentages[3] = amount * 15 / 1000;

            // 找四层
            for (uint256 i = 0; i < 4; i++) {
                // 获取邀请人
                address nowAddress = aTokenContract.getReferrer(to);
                // 如果没有邀请人，销毁
                if (nowAddress == address(0)) {
                    _basicTransfer(from, DEAD, rewardPercentages[i]);
                    break;
                }
                // 获取地址是否加池超过18.8USDT，如果小于18.8USDT，就销毁了，不发放. 钱包持有LP/总发行LP*LP持有USDT(钱包持有LP*LP持有USDT/总发行LP)
                if (usdtPair.balanceOf(nowAddress) * IUsdt.balanceOf(address(uniswapV2PairUSDT)) / usdtPair.totalSupply() < (98 * 10 ** (_decimals - 1))) {
                    _basicTransfer(from, DEAD, rewardPercentages[i]);
                    break;
                }
                // 大于18.8USDT，正常发放
                _basicTransfer(from, nowAddress, rewardPercentages[i]);
            }

        } else {
            // 如果是普通钱包转账，直接销毁5%
            _basicTransfer(from, DEAD, payFee);
        }

        return amount - payFee;
    }

    // xxbb 获取钱包加池LP的USDT数量
    function getLPPrice(address nowAddress) public view returns(uint256){
        return usdtPair.balanceOf(nowAddress) * IUsdt.balanceOf(address(uniswapV2PairUSDT)) / usdtPair.totalSupply();
    }

    //xxbb 获取指定数量的token，对应另一个指定token的价格.一般传参usdt和自身代币数量
    function getPrice(address token,uint256 amount) public view returns(uint256){
        address[] memory allAddress = new address[](2);
        allAddress[0] = address(this);
        allAddress[1] = token;

        uint[] memory price = uniswapV2Router.getAmountsOut(amount,allAddress);

        return price[1];
    }

    //xxbb
    function get24HourTransfers(address _wallet) private returns (uint256) {

        uint256 amount = 0;
        uint256 crrunt = 0;
        // 循环所有买入交易记录
        for (uint256 i = 0; i < payTransfers[_wallet].length; i++) {
            if (block.timestamp - payTransfers[_wallet][i].timestamp > 3 hours) {
                // 如果超过24小时了，记入计数器，用于删除
                crrunt++;
            }else {
                //如果不到24小时的交易，计算总金额
                amount += payTransfers[_wallet][i].amount;
            }
        }
        //删除所有超过24小时的交易
        if(crrunt > 0){
            if(crrunt > payTransfers[_wallet].length){
                while (payTransfers[_wallet].length > 0) {
                    payTransfers[_wallet].pop();
                }
            }
            for (uint256 i = 0; i < payTransfers[_wallet].length - crrunt; i++) {
                payTransfers[_wallet][i] = payTransfers[_wallet][i + crrunt];
            }
            for (uint256 i = 0; i < crrunt; i++) {
                payTransfers[_wallet].pop();
            }
        }

        return (amount);
    }

    // 第一年增发：52.8万；第二年：264万；第三年：528万；firstIssueTime 本就是次年，所以这里不需要currentIssueCount + 1
    function additionalIssue() private {
        if(currentIssueCount == 0 && _lastRebasedTime > 0 && block.timestamp > firstIssueTime){
            uint256 amount = 528000 * 10 ** _decimals;
            _balances[issueAddress] = _balances[issueAddress] + amount;

            _trueTotalSupply = _trueTotalSupply + amount;

            currentIssueCount = 1;
        }
        if(currentIssueCount == 1 && block.timestamp > (firstIssueTime + 1 * 15 minutes)){
            uint256 amount = 2640000 * 10 ** _decimals;
            _balances[issueAddress] = _balances[issueAddress] + amount;

            _trueTotalSupply = _trueTotalSupply + amount;

            currentIssueCount = 2;
        }
        if(currentIssueCount == 2 && block.timestamp > (firstIssueTime + 2 * 15 minutes)){
            uint256 amount = 5280000 * 10 ** _decimals;
            _balances[issueAddress] = _balances[issueAddress] + amount;

            _trueTotalSupply = _trueTotalSupply + amount;

            currentIssueCount = 3;
        }
        if(currentIssueCount < 23 && currentIssueCount > 2 && block.timestamp > (firstIssueTime + currentIssueCount * 15 minutes)){
            uint256 amount = (5271552000 / 100 * 5) * 10 ** _decimals;
            _balances[issueAddress] = _balances[issueAddress] + amount;

            _trueTotalSupply = _trueTotalSupply + amount;

            currentIssueCount = currentIssueCount + 1;
        }
        return;
    }

}
