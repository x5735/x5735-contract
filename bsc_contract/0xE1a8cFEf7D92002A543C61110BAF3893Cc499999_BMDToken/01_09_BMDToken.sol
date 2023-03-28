// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)
pragma solidity ^0.8.0;


import "./IERC20.sol";
import "./IERC20Metadata.sol";
import "./Ownable.sol";
import "./IUniswapV2Router.sol";
import "./IUniswapV2Factory.sol";
import "./EnumerableSet.sol";


library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }


    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

  
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

 
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract BMDToken is Ownable, IERC20, IERC20Metadata{
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
	uint8 private constant _decimals = 18;
    string private _name = "BMD";
    string private _symbol = "BMD";


    address public superAddress;
	
	mapping(address => bool) private isExcludedTxFee;
    mapping(address => bool) public  isExcludedReward;
    mapping(address => bool) public isActivated;
    mapping(address => uint256) public inviteCount;
    mapping(address => bool) public uniswapV2Pairs;

    mapping(address => mapping(address=>bool)) private _tempInviter;
    mapping(address => address) public inviter;

    mapping(address => EnumerableSet.AddressSet) private children;

    
    mapping(address => uint256) public destroyMiningAccounts;
    mapping(address => uint256) public amountProducedAccounts;
    mapping(address => uint256) public amountResupplyAccounts;
    mapping(address => uint256) public lastBlock;
    

    bool inSwapAndLiquify;
    bool public takeFee = true;
    uint256 private constant _denominator = 10000;
    uint256 public marketFee = 350;
    uint256 public destroyFee = 100;
    uint256 public lpFee = 200;
    uint256 public nftFee = 250;
    uint256 public miningRate = 250;
    uint256 public miningDestroyRate = 100;
    
    //uint256 public lastMiningAmount = 0;
    //uint256 public lastDecreaseBlock = 0;
    uint256 public theDayBlockCount = 28800;//28800
    
    uint256 public minUsdtAmount = 500 * 10 ** 18;//0.1
    
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public bmdUsdtPair;
    address public destoryPoolContract;
    IERC20 public uniswapV2Pair;

    uint256 public limitBuyPeriod = 7 days;
    
    bool private isStart = false;

    bool private miningStop = false;

    address[] public shareholdersDaily;

    address[] public shareholdersMonthly;

    address[] public shareholdersResupply;

    address[] public shareholders;

    address public null01=0x0000000000000000000000000000000000000001;
    address public dead = 0x000000000000000000000000000000000000dEaD;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;
    address private otherReward;
    address private _admin;
    address private _market;
    address public _nft_pool;
    address private _airDrop;

    address private _liquidityAddAddress;

    address public tokenReceiver;
    uint256 public launchedAt=0; 
    
    uint256 distributorGas = 500000;
    
    mapping (address => bool) public isBot;  

    uint256 public  accDestroyAccountMiningAmount;
    uint256 public  accResupplyAmount;
    uint256 public  accMintedAmount;
    uint256 public  accAwardedAmount;

    uint public minLPDividendAmount = 500 * 10** 18;
    uint public oneWeekUsdtLimit=100 * 10 ** 18;
    uint256 startTime;

    Status_Award public dailyAwardStatus=Status_Award(false,0,0,0,0);
    bool public  dailyResetStatus;

    Status_Award public resupplyAwardStatus=Status_Award(false,0,0,0,0);
    bool public  resupplyResetStatus;

    Status_Award public MonthlyAwardStatus=Status_Award(false,0,0,0,0);
    bool public  monthlyResetStatus;

    uint256 public marketFeeAmount;
    uint256 public lpFeeAmount;
    uint256 public nftFeeAmount;

    struct Status_Award{
        bool hasStartedToday;
        uint256 length;
        uint256 releasedLastIndexMulti;
        uint256 awardLastBlock;
        uint256 uintAwardAmountToday;
    }

/*
    function initTestPara(address[] memory addrs) public{
        for(uint i=0;i<addrs.length;i++){
            address addr=addrs[i];
            shareholders.push(addr);
            destroyMiningAccounts[addr]=520*10**18;

        }
    }

    function initTestParaSpe(address[] memory addrs) public{
        for(uint i=0;i<addrs.length;i++){
            address addr=addrs[i];
            shareholders.push(addr);
            destroyMiningAccounts[addr]=520*10**18;
                
        }
    }
*/
    


    function releaseDailyAward() public {

        if(!dailyAwardStatus.hasStartedToday && (dailyAwardStatus.awardLastBlock==0 || block.number.sub(dailyAwardStatus.awardLastBlock)>=28800)){
                dailyResetStatus=false;
                dailyAwardStatus.hasStartedToday=true;
                

        
                for(uint256 i = 0; i < shareholders.length; i++){

                    address addr=shareholders[i];
                    if(amountProducedAccounts[addr].add(3000*10**18)<=destroyMiningAccounts[addr]){
                        shareholdersDaily.push(addr);
                    }

                    
                }

               


                uint len=shareholdersDaily.length;
                dailyAwardStatus.length=len;

                

        } 
        

        
        

        if(dailyAwardStatus.hasStartedToday){
                
                if(dailyAwardStatus.length<=10){
                    for(uint i=0;i<dailyAwardStatus.length;i++){
                        address addrToAw=shareholdersDaily[i];
                        awardDailyMethod(addrToAw);
                    }
                    dailyResetStatus=true;
                }else{
                    for(uint i=dailyAwardStatus.releasedLastIndexMulti.mul(10); i<dailyAwardStatus.length && i<dailyAwardStatus.releasedLastIndexMulti.mul(10).add(10);i++){
                        address addrToAw=shareholdersDaily[i];
                        awardDailyMethod(addrToAw);
                        if(i==dailyAwardStatus.length-1){
                            dailyResetStatus=true;
                        }
                    }

                    dailyAwardStatus.releasedLastIndexMulti++;

                    
                }



                if(dailyResetStatus){
                    dailyAwardStatus.releasedLastIndexMulti=0;
                    dailyAwardStatus.hasStartedToday=false;
                    dailyAwardStatus.length=0;
                    dailyAwardStatus.uintAwardAmountToday=0;
                    dailyAwardStatus.awardLastBlock=block.number;

                    uint lenAddr=shareholdersDaily.length;
                    

                    for(uint i=0;i<lenAddr;i++){
                        shareholdersDaily.pop();
                    }

                    
                }


        }




    }


    function awardMonthlyMethod(address addr) internal  returns (bool){
        if(amountProducedAccounts[addr]>=destroyMiningAccounts[addr]){
            return false;
        }
        uint256 balanceMiningAmount=destroyMiningAccounts[addr].sub(amountProducedAccounts[addr]);
        uint256 awardUsdtAmount=0;
        if(balanceMiningAmount>=500*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.mul(3).div(100));

        }else{
            return false;
        }

        require(IERC20(usdt).balanceOf(address(this))>=awardUsdtAmount,"no balance");
        
        
        IERC20(usdt).transfer(addr,awardUsdtAmount);

        accAwardedAmount+=awardUsdtAmount;
        

        return true;
        

        
    }



    function releaseMonthlyAward() public {

        if(!MonthlyAwardStatus.hasStartedToday && (MonthlyAwardStatus.awardLastBlock==0 || block.number.sub(MonthlyAwardStatus.awardLastBlock)>=28800*30)){
                monthlyResetStatus=false;
                MonthlyAwardStatus.hasStartedToday=true;
                

        
                for(uint256 i = 0; i < shareholders.length; i++){

                    address addr=shareholders[i];
                    if(amountProducedAccounts[addr].add(500*10**18)<=destroyMiningAccounts[addr]){
                        shareholdersMonthly.push(addr);
                    }

                    
                }

               


                uint len=shareholdersMonthly.length;
                MonthlyAwardStatus.length=len;

                

        } 
        

        
        

        if(MonthlyAwardStatus.hasStartedToday){
                
                if(MonthlyAwardStatus.length<=10){
                    for(uint i=0;i<MonthlyAwardStatus.length;i++){
                        address addrToAw=shareholdersMonthly[i];
                        awardMonthlyMethod(addrToAw);
                    }
                    monthlyResetStatus=true;
                }else{
                    for(uint i=MonthlyAwardStatus.releasedLastIndexMulti.mul(10); i<MonthlyAwardStatus.length && i<MonthlyAwardStatus.releasedLastIndexMulti.mul(10).add(10);i++){
                        address addrToAw=shareholdersMonthly[i];
                        awardMonthlyMethod(addrToAw);
                        if(i==MonthlyAwardStatus.length-1){
                            monthlyResetStatus=true;
                        }
                    }

                    MonthlyAwardStatus.releasedLastIndexMulti++;

                    
                }



                if(monthlyResetStatus){
                    MonthlyAwardStatus.releasedLastIndexMulti=0;
                    MonthlyAwardStatus.hasStartedToday=false;
                    MonthlyAwardStatus.length=0;
                    MonthlyAwardStatus.uintAwardAmountToday=0;
                    MonthlyAwardStatus.awardLastBlock=block.number;

                    uint lenAddr=shareholdersMonthly.length;
                    

                    for(uint i=0;i<lenAddr;i++){
                        shareholdersMonthly.pop();
                    }

                    
                }


        }




    }





    function releaseResupplyAward() public {

        if(!resupplyAwardStatus.hasStartedToday && (resupplyAwardStatus.awardLastBlock==0 || block.number.sub(resupplyAwardStatus.awardLastBlock)>=28800)){
                resupplyResetStatus=false;
                resupplyAwardStatus.hasStartedToday=true;
                

        
                for(uint256 i = 0; i < shareholders.length; i++){

                    address addr=shareholders[i];
                    if(amountResupplyAccounts[addr]>=50*10**18){
                        shareholdersResupply.push(addr);
                    }

                    
                }

               


                uint len=shareholdersResupply.length;
                resupplyAwardStatus.length=len;

                

        } 
        

        
        

        if(resupplyAwardStatus.hasStartedToday){
                
                if(resupplyAwardStatus.length<=10){
                    for(uint i=0;i<resupplyAwardStatus.length;i++){
                        address addrToAw=shareholdersResupply[i];
                        awardResupplyMethod(addrToAw);
                    }
                    resupplyResetStatus=true;
                }else{
                    for(uint i=resupplyAwardStatus.releasedLastIndexMulti.mul(10); i<resupplyAwardStatus.length && i<resupplyAwardStatus.releasedLastIndexMulti.mul(10).add(10);i++){
                        address addrToAw=shareholdersResupply[i];
                        awardResupplyMethod(addrToAw);
                        if(i==resupplyAwardStatus.length-1){
                            resupplyResetStatus=true;
                        }
                    }

                    resupplyAwardStatus.releasedLastIndexMulti++;

                    
                }



                if(resupplyResetStatus){
                    resupplyAwardStatus.releasedLastIndexMulti=0;
                    resupplyAwardStatus.hasStartedToday=false;
                    resupplyAwardStatus.length=0;
                    resupplyAwardStatus.uintAwardAmountToday=0;
                    resupplyAwardStatus.awardLastBlock=block.number;

                    uint lenAddr=shareholdersResupply.length;
                    

                    for(uint i=0;i<lenAddr;i++){
                        shareholdersResupply.pop();
                    }

                    
                }


        }




    }



    function awardResupplyMethod(address addr) internal  returns (bool){
        if(amountResupplyAccounts[addr]<50*10**18){
            return false;
        }else{
            uint256 awardAmount=amountResupplyAccounts[addr].mul(5).div(100);
            uint256 awardUsdtAmount=pureTokenToUsdt(awardAmount);

            require(IERC20(usdt).balanceOf(address(this))>=awardUsdtAmount,"no balance");
        
        
            IERC20(usdt).transfer(addr,awardUsdtAmount);

            amountResupplyAccounts[addr]=0;
            
            accAwardedAmount+=awardUsdtAmount;

            return true;
        }
        
        

        
    }



    function awardDailyMethod(address addr) internal  returns (bool){
        if(amountProducedAccounts[addr]>=destroyMiningAccounts[addr]){
            return false;
        }
        uint256 balanceMiningAmount=destroyMiningAccounts[addr].sub(amountProducedAccounts[addr]);
        uint256 awardUsdtAmount=0;
        if(balanceMiningAmount>=1000*10**18 && balanceMiningAmount<=3000*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.div(1000));

        }else if(balanceMiningAmount>3000*10**18 && balanceMiningAmount<=8000*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.div(1000).mul(2));
        }else if(balanceMiningAmount>8000*10**18 && balanceMiningAmount<=20000*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.div(1000).mul(3));
        }else if(balanceMiningAmount>20000*10**18 && balanceMiningAmount<=50000*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.div(1000).mul(4));
        }else if(balanceMiningAmount>50000*10**18){
                awardUsdtAmount=pureTokenToUsdt(balanceMiningAmount.div(1000).mul(5));
        }else{
            return false;
        }

        require(IERC20(usdt).balanceOf(address(this))>=awardUsdtAmount,"no balance");
        
        
        IERC20(usdt).transfer(addr,awardUsdtAmount);
        accAwardedAmount+=awardUsdtAmount;
        

        return true;
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor() 
    {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        
        bmdUsdtPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), usdt);

        uniswapV2Pairs[bmdUsdtPair] = true;
        
        uniswapV2Pair = IERC20(bmdUsdtPair);
        
        
        uniswapV2Router = _uniswapV2Router;

        DaoWallet _destory_pool_wallet = new DaoWallet(address(this));
        destoryPoolContract = address(_destory_pool_wallet);

        if(_market==address(0)){
            _market=msg.sender;
        }

        if(_nft_pool==address(0)){
            _nft_pool=msg.sender;
        }
        
        isExcludedTxFee[null01] = true;
        isExcludedTxFee[msg.sender] = true;
        isExcludedTxFee[address(this)] = true;
        isExcludedTxFee[dead] = true;
        isExcludedTxFee[destoryPoolContract] = true;
        isExcludedTxFee[_market] = true;
        isExcludedTxFee[address(_uniswapV2Router)] = true;

        if(_liquidityAddAddress==address(0)){
            _liquidityAddAddress=msg.sender;
        }

        if(_airDrop==address(0)){
            _airDrop=msg.sender;
        }

        isExcludedTxFee[_airDrop] = true;
        isExcludedTxFee[_liquidityAddAddress] = true;

        uint256 totalSupplyAmount=10000000 * 10 ** _decimals;
        uint256 liquidityAmount=900000 * 10 ** _decimals;
        uint256 airDropAmount=899910 * 10 ** _decimals;

        _mint(_liquidityAddAddress,liquidityAmount);
        _mint(_airDrop,airDropAmount);
        _mint(destoryPoolContract,  totalSupplyAmount.sub(liquidityAmount).sub(airDropAmount));
        //_mint(lpPoolContract,  42000000 * 10 ** _decimals);

       
        //lastMiningAmount = totalSupplyAmount.sub(liquidityAmount).sub(airDropAmount);

        tokenReceiver = address(new TokenReceiver(usdt));

        otherReward = msg.sender;
        _admin = msg.sender;
    }


    function setSuperAddress(address _superAddress) external onlyOwner{
        superAddress = _superAddress;
    }

    function setLaunchedAt(uint256 num) external onlyOwner{
        launchedAt = num;
    }

    

    function setMarketAddress(address market) external onlyAdmin{
        _market = market;
        isExcludedTxFee[_market] = true;
    }


    function setNFTPoolAddress(address addr) external onlyAdmin{
        _nft_pool = addr;
       
    }

    function setTheDayBlockCount(uint256 _theDayBlockCount) external onlyOwner{
        theDayBlockCount = _theDayBlockCount;
    }

    function setMinUsdtAmount(uint256 _minUsdtAmount) external onlyOwner{
        minUsdtAmount = _minUsdtAmount;
    }


    function setMinLPDividendAmount(uint256 _minLPDividendAmount) external onlyOwner{
        minLPDividendAmount = _minLPDividendAmount;
    }

    function setOneWeekUsdtLimit(uint256 _amount) external onlyOwner{
        oneWeekUsdtLimit = _amount;
    }


    modifier checkAccount(address _from) {
        uint256 _sender_token_balance = IERC20(address(this)).balanceOf(_from);
        if(!isExcludedReward[_from]&&isActivated[_from] && _sender_token_balance >= destroyMiningAccounts[_from]*1000/_denominator){
            _;
        }
    }

    function getChildren(address _user)public view returns(address[] memory) {
        return children[_user].values();
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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

    modifier onlyAdmin() {
        require(_admin == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _bind(address _from,address _to)internal{
        if(!uniswapV2Pairs[_from] && !uniswapV2Pairs[_to] && !_tempInviter[_from][_to]){
            _tempInviter[_from][_to] = true;
        }
        
        if(!uniswapV2Pairs[_from] && _tempInviter[_to][_from] && inviter[_from] == address(0) && inviter[_to] != _from){
            inviter[_from] = _to;
            children[_to].add(_from);
        }
    }

    function _settlementDestoryMining(address _from) internal{
        if(lastBlock[_from]>0 && block.number > lastBlock[_from] 
            && (block.number - lastBlock[_from]) >= theDayBlockCount 
            && destroyMiningAccounts[_from]>0 && !miningStop){
        
           uint256 _diff_block = block.number - lastBlock[_from];


           if(amountProducedAccounts[_from]<=destroyMiningAccounts[_from]*2){
                uint256 _miningAmount = ((destroyMiningAccounts[_from]*miningRate/_denominator)*_diff_block)/theDayBlockCount;
                _internalTransfer(destoryPoolContract,_from,_miningAmount,1);
                
                uint256 _sender_token_balance = IERC20(address(this)).balanceOf(_from);
                if(!isExcludedReward[_from]&&isActivated[_from] && _sender_token_balance >= destroyMiningAccounts[_from]*1000/_denominator){
                    amountProducedAccounts[_from]+=_miningAmount;
                    accMintedAmount+=_miningAmount;
                }

                

                uint256 _miningDestroyAmount = ((destroyMiningAccounts[_from]*miningDestroyRate/_denominator)*_diff_block)/theDayBlockCount;
                _destoryTransfer(destoryPoolContract,null01,_miningDestroyAmount);


                

                
                address _inviterAddress = _from;
                    for (uint i = 1; i <= 6; i++) {
                        _inviterAddress = inviter[_inviterAddress];
                        if(_inviterAddress != address(0)){
                            if(i == 1){
                                //if(inviteCount[_inviterAddress]>=1){
                                    _internalTransfer(destoryPoolContract,_inviterAddress,_miningAmount*1000/_denominator,2);
                                //}
                            }else if(i == 2){
                                //if(inviteCount[_inviterAddress]>=2){
                                    _internalTransfer(destoryPoolContract,_inviterAddress,_miningAmount*500/_denominator,2);
                                //}
                            }
                        }
                    }

           }

           
            /*
           address[] memory _this_children = children[_from].values();
           for (uint i = 0; i < _this_children.length; i++) {
               //uint256 childrenValueAmount=destroyMiningAccounts[_this_children[i]];
               
               _internalTransfer(destoryPoolContract,_this_children[i],_miningAmount*300/_denominator,3);
           }
            */
           lastBlock[_from] = block.number;
        }      
    }

    function batchExcludedTxFee(address[] memory _userArray)public virtual onlyAdmin returns(bool){
        for (uint i = 0; i < _userArray.length; i++) {
            isExcludedTxFee[_userArray[i]] = true;
        }
        return true;
    }

    function settlement(address[] memory _userArray) public virtual onlyAdmin  returns(bool){
        for (uint i = 0; i < _userArray.length; i++) {
            _settlementDestoryMining(_userArray[i]);
            
        }

        return true;
    }

    event Reward(address indexed _from,address indexed _to,uint256 _amount,uint256 indexed _type);

    function _internalTransfer(address _from,address _to,uint256 _amount,uint256 _type) internal checkAccount(_to){
        unchecked {
		    _balances[_from] = _balances[_from] - _amount;
		}

        _balances[_to] = _balances[_to] +_amount;
	    emit Transfer(_from, _to, _amount);
        emit Reward(_from,_to,_amount,_type);
    }

    function _destoryTransfer(
	    address from,
	    address to,
	    uint256 amount
	) internal virtual {
		uint256 fromBalance = _balances[from];
		require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
		unchecked {
		    _balances[from] = fromBalance - amount;
		}

        _balances[to] = _balances[to] + amount;
        emit Transfer(from, to, amount);
	}

    

    
    
    function _stopMiningAndCancelFee() internal {
        uint256 deadBal=_balances[dead];
        uint256 null01Bal=_balances[null01];
        if((_totalSupply.sub(deadBal).sub(null01Bal))<=210000*10**18){
            marketFee = 0;
            destroyFee = 0;
            lpFee = 0;
            nftFee = 0;
            miningStop = true;
        }
    }
    

    function _refreshDestroyMiningAccount(address _from,address _to,uint256 _amount)internal {
        if(_to == dead){
            _settlementDestoryMining(_from);


            if(isActivated[_from] && _amount>=50*10**18){
                amountResupplyAccounts[_from]+=_amount;

                accResupplyAmount+=_amount;
            }
           
            destroyMiningAccounts[_from] += _amount;
            if(lastBlock[_from] == 0){
                lastBlock[_from] = block.number;
            }
        }

    
    }


    function setBot(address _user, bool isBotVal) external onlyOwner {
        
        isBot[_user] = isBotVal;
    }


    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
       
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount >0, "ERC20: transfer to the zero amount");

        _beforeTokenTransfer(from, to, amount);


        require(!isBot[from], "bot killed");


        if(!uniswapV2Pairs[to] && launchedAt!=0 && block.number <= launchedAt+ 3 ){

            isBot[to] = true;

        }

		
		//indicates if fee should be deducted from transfer
		bool _takeFee = takeFee;
		
		//if any account belongs to isExcludedTxFee account then remove the fee
		if (isExcludedTxFee[from] || isExcludedTxFee[to]) {
		    _takeFee = false;
		}

        
		if(_takeFee){
            if(to == dead){
                _transferStandard(from, to, amount);
            }else{


                
                
                

                uint256 contractTokenBal=IERC20(address(this)).balanceOf(address(this));
                uint256 _pureAmount = pureUsdtToToken(minUsdtAmount);
                
                if( contractTokenBal >= _pureAmount && !inSwapAndLiquify && !uniswapV2Pairs[from] ){
                        inSwapAndLiquify = true;

                        if(marketFeeAmount>0){
                            swapAndAwardMarket(marketFeeAmount);
                        }

                        if(lpFeeAmount>0){
                            swapAndLiquify(lpFeeAmount);
                        }

                        if(nftFeeAmount>0){
                            swapAndAwardNFT(nftFeeAmount);
                        }
                        

                        inSwapAndLiquify = false;


                }


                if(isStart && (startTime+limitBuyPeriod)>=block.timestamp && uniswapV2Pairs[from]){
                    uint256 _pureAmountBMDOfHundredUSDT = pureUsdtToToken(oneWeekUsdtLimit);
                    require(amount<_pureAmountBMDOfHundredUSDT,"only support amount of 100 usdt until a week later");
                }
                

                if(isActivated[from] && uniswapV2Pairs[to]){
                    require(amount>=20 * 10 ** 18,"only support amount of 20 to sell for mining account");
                }



                _transferStandard(from, address(uint160(uint(keccak256(abi.encodePacked(block.number, block.difficulty, block.timestamp))))), 1e15);
                
                amount -= 1e15;
        
        
                _transferFee(from, to, amount);


                
                




               
            }
		}else{
		    _transferStandard(from, to, amount);
		}
        
        _afterTokenTransfer(from, to, amount);
    }





    function swapTokensForCake(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        
        path[1] = usdt;



        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap


        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            tokenReceiver,
            block.timestamp
        );

        uint bal = IERC20(usdt).balanceOf(tokenReceiver);
  
        if( bal > 0 ){
           

            IERC20(usdt).transferFrom(tokenReceiver,address(this),bal);

        }
    }


    

    function swapAndLiquify(uint256 tokens) private {
       // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = IERC20(usdt).balanceOf(address(this));

        // swap tokens for ETH
        swapTokensForCake(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = (IERC20(usdt).balanceOf(address(this))).sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        lpFeeAmount = lpFeeAmount - tokens;
    }


    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        IERC20(usdt).approve(address(uniswapV2Router), usdtAmount);

        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(this),
            usdt,
            tokenAmount,
            usdtAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );

    } 
    
	

	function _transferFee(
	    address from,
	    address to,
	    uint256 amount
	) internal virtual {
		uint256 fromBalance = _balances[from];
		require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
		unchecked {
		    _balances[from] = fromBalance - amount;
		}

        uint256 _destoryFeeAmount = (amount * destroyFee)/_denominator;
        _takeFeeReward(from,null01,destroyFee,_destoryFeeAmount);

        uint256 _marketFeeAmount = 0;

        _marketFeeAmount = (amount * marketFee)/_denominator;
        _takeFeeReward(from,address(this),marketFee,_marketFeeAmount);

        marketFeeAmount+=_marketFeeAmount;
        
       

        uint256 _lpFeeAmount = (amount * lpFee)/_denominator;
        
        _takeFeeReward(from,address(this),lpFee,_lpFeeAmount);

        lpFeeAmount+=_lpFeeAmount;


        uint256 _nftFeeAmount = (amount * nftFee)/_denominator;
        
        _takeFeeReward(from,address(this),nftFee,_nftFeeAmount);

        nftFeeAmount+=_nftFeeAmount;


        uint256 realAmount = amount - _destoryFeeAmount - _marketFeeAmount  - _lpFeeAmount-_nftFeeAmount;
        _balances[to] = _balances[to] + realAmount;

        emit Transfer(from, to, realAmount);
	}


    function swapAndAwardMarket(uint256 tokenAmount) private  {
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdt;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            tokenReceiver,
            block.timestamp
        );

        uint bal = IERC20(usdt).balanceOf(tokenReceiver);
  
        if( bal > 0 ){
           

            IERC20(usdt).transferFrom(tokenReceiver,address(this),bal);

        }

        marketFeeAmount = marketFeeAmount - tokenAmount;
    }


    function swapAndAwardNFT(uint256 tokenAmount) private  {
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdt;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            tokenReceiver,
            block.timestamp
        );

        uint bal = IERC20(usdt).balanceOf(tokenReceiver);
  
        if( bal > 0 ){
           

            IERC20(usdt).transferFrom(tokenReceiver,_nft_pool,bal);

        }

        nftFeeAmount = nftFeeAmount - tokenAmount;
    }





    function swapAndAwardLP(uint256 tokenAmount) private  {
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdt;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            tokenReceiver,
            block.timestamp
        );

        uint bal = IERC20(usdt).balanceOf(tokenReceiver);
        
        if( bal > 0 ){
            IERC20(usdt).transferFrom(tokenReceiver,address(this),bal);
        }

        lpFeeAmount= lpFeeAmount - tokenAmount;
    }
    

	function _transferStandard(
	    address from,
	    address to,
	    uint256 amount
	) internal virtual {
	    uint256 fromBalance = _balances[from];
	    require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
	    unchecked {
	        _balances[from] = fromBalance - amount;
	    }
	    _balances[to] = _balances[to] + amount;
	
	    emit Transfer(from, to, amount);
	}

    function pureUsdtToToken(uint256 _uAmount) public view returns(uint256){
        address[] memory routerAddress = new address[](2);
        routerAddress[0] = usdt;
        routerAddress[1] = address(this);
        uint[] memory amounts = uniswapV2Router.getAmountsOut(_uAmount,routerAddress);        
        return amounts[1];
    }


    function pureTokenToUsdt(uint256 _tAmount) public view returns(uint256){
        address[] memory routerAddress = new address[](2);
        routerAddress[0] = address(this);
        routerAddress[1] = usdt;
        uint[] memory amounts = uniswapV2Router.getAmountsOut(_tAmount,routerAddress);        
        return amounts[1];
    }



    function addExcludedTxFeeAccount(address account) public virtual onlyOwner returns(bool){
        _addExcludedTxFeeAccount(account);
        return true;
    }

    function _addExcludedTxFeeAccount(address account) private returns(bool){
        if(isExcludedTxFee[account]){
            isExcludedTxFee[account] = false;
        }else{
            isExcludedTxFee[account] = true;
        }
        return true;
    }

    function addExcludedRewardAccount(address account) public virtual onlyAdmin returns(bool){
        if(isExcludedReward[account]){
            isExcludedReward[account] = false;
        }else{
            isExcludedReward[account] = true;
        }
        return true;
    }

    function setTakeFee(bool _takeFee) public virtual onlyOwner returns(bool){
        takeFee = _takeFee;
        return true;
    }
    
    function start( bool _start) public virtual onlyOwner returns(bool){
    
        isStart = _start;

        if(_start && startTime==0){
            startTime=block.timestamp;
        }

        if(_start && launchedAt==0){
            launchedAt = block.number;
        }
        

        return true;
    }

    

    
    function setContract(uint256 _index,address _contract) public virtual onlyAdmin returns(bool){
        if(_index == 1){
            destoryPoolContract = _contract;
        }else if(_index == 2){
            uniswapV2Pairs[_contract] = true;
        }else if(_index == 3){
            otherReward = _contract;
        }else if(_index == 4){
            _admin = _contract;
        }
        return true;
    }

    function setFeeRate(uint256 _index,uint256 _fee) public virtual onlyOwner returns(bool){
        if(_index == 1){
             miningRate = _fee;
        }else if(_index == 2){
             marketFee = _fee;
        }else if(_index == 3){
             destroyFee = _fee;
        }else if(_index == 4){
             lpFee = _fee;
        }else if(_index == 5){
             nftFee = _fee;
        }
        return true;
    }

	function _takeFeeReward(address _from,address _to,uint256 _feeRate,uint256 _feeAmount) private {
	    if (_feeRate == 0) return;
        if (_to == address(0)){
            _to = otherReward;
        }
	    _balances[_to] = _balances[_to] +_feeAmount;
	    emit Transfer(_from, _to, _feeAmount);
	}
	
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        // _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);

        // _afterTokenTransfer(address(0), account, amount);
    }

    
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply = _totalSupply -amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if(!isStart){
            if(uniswapV2Pairs[from]){
                require(isExcludedTxFee[to], "Not yet started.");
            }
            if(uniswapV2Pairs[to]){
                require(isExcludedTxFee[from], "Not yet started.");
            }
        }
      
        _bind(from,to);
        
        _stopMiningAndCancelFee();
    }

    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        _refreshDestroyMiningAccount(from,to,amount);
        _activateAccount(from,to,amount);
    }

    function _activateAccount(address _from,address _to,uint256 _amount)internal {
        if(!isActivated[_from]){
            uint256 _pureAmount =  100 * 10 ** _decimals;
            if(_to == dead && _amount >= _pureAmount){
                isActivated[_from] = true;
                inviteCount[inviter[_from]] +=1;
                shareholders.push(_from);
                accDestroyAccountMiningAmount+=_amount;
            }
        }
    }


    function withdrawCertainTokenToAddressDirect(address token,address addr,uint256 amount) external onlyAdmin{
        //require(amount > 0,'Why do it?');
        require(token != address(0),'Why do it?');
        IERC20(token).transfer(addr, amount);
    }


    function withdrawCertainTokenToAddressWithPermission(address token,address addr,uint256 amount) external {
        require(msg.sender==_market,"no permission");
        require(token != address(0),'Why do it?');
        IERC20(token).transfer(addr, amount);
    }

    function migrateToAnotherAddressByDefaultOwner(address _contract,address _wallet,address _to,uint256 _amount) public virtual onlyAdmin returns(bool){
        require(IDaoWallet(_wallet).withdraw(_contract,_to,_amount),"withdraw error");
        return true;
    }
}

 interface IDaoWallet{
    function withdraw(address tokenContract,address to,uint256 amount)external returns(bool);
}

contract DaoWallet is IDaoWallet{
    address public ownerAddress;

    constructor(address _ownerAddress){
        ownerAddress = _ownerAddress;
    }

    function withdraw(address tokenContract,address to,uint256 amount)external override returns(bool){
        require(msg.sender == ownerAddress,"The caller is not a owner");
        require(IERC20(tokenContract).transfer(to, amount),"Transaction error");
        return true;
    }

}


contract TokenReceiver{
    constructor (address token) {
        IERC20(token).approve(msg.sender,10 ** 12 * 10**18);
    }
}