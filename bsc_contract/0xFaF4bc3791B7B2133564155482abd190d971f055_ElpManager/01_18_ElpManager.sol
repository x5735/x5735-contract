// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./VaultMSData.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IElpManager.sol";
import "../tokens/interfaces/IUSDX.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../DID/interfaces/IESBT.sol";

pragma solidity ^0.8.0;

contract ElpManager is ReentrancyGuard, Ownable, IElpManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDX_DECIMALS = 10 ** 18;
    uint256 public constant MAX_COOLDOWN_DURATION = 48 hours;
    
    uint256 public constant WEIGHT_PRECISSION = 1000000;

    IVault public vault;
    address public elp;
    address public weth;
    address public esbt;

    uint256 public override cooldownDuration;
    mapping(address => uint256) public override lastAddedAt;

    uint256 public aumAddition;
    uint256 public aumDeduction;

    bool public inPrivateMode;
    mapping(address => bool) public isHandler;

    event AddLiquidity(
        address account,
        address token,
        uint256 amount,
        uint256 aumInUsdx,
        uint256 elpSupply,
        uint256 usdxAmount,
        uint256 mintAmount
    );

    event RemoveLiquidity(
        address account,
        address token,
        uint256 elpAmount,
        uint256 aumInUsdx,
        uint256 elpSupply,
        uint256 usdxAmount,
        uint256 amountOut
    );

    constructor(address _vault, address _elp, uint256 _cooldownDuration,address _weth) {
        vault = IVault(_vault);
        elp = _elp;
        cooldownDuration = _cooldownDuration;
        weth = _weth;
    }
    receive() external payable {
        require(msg.sender == weth, "invalid sender");
    }
    
    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setInPrivateMode(bool _inPrivateMode) external onlyOwner {
        inPrivateMode = _inPrivateMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    function setESBT(address _esbt) external onlyOwner {
        esbt = _esbt;
    }

    function setCooldownDuration(uint256 _cooldownDuration) external onlyOwner {
        require(_cooldownDuration <= MAX_COOLDOWN_DURATION, "ElpManager: invalid _cooldownDuration");
        cooldownDuration = _cooldownDuration;
    }

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external onlyOwner {
        aumAddition = _aumAddition;
        aumDeduction = _aumDeduction;
    }

    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdx, uint256 _minElp) external override nonReentrant returns (uint256) {
        if (inPrivateMode) { revert("ElpManager: action not enabled"); }
        return _addLiquidity(msg.sender, msg.sender, _token, _amount, _minUsdx, _minElp);
    }


    function addLiquidityETH() external nonReentrant payable returns (uint256) {
        if (inPrivateMode) { revert("ElpManager: action not enabled"); }
        if (msg.value < 1) {
            return 0;
        }
        IWETH(weth).deposit{value: msg.value}();
        address _account = msg.sender;
        uint256 _amount = msg.value;
        address _token = weth;
        uint256 aumInUSD = getAumInUSD(true);
        uint256 elpSupply = IERC20(elp).totalSupply();
        IERC20(weth).safeTransfer(address(vault), _amount);
        uint256 usdxAmount = vault.buyUSDX(_token, address(this));
        // require(usdxAmount >= _minUsdx, "buyin slippage Error");
        uint256 mintAmount = aumInUSD == 0 ? usdxAmount : usdxAmount.mul(elpSupply).div(aumInUSD);
        // require(mintAmount >= _minElp, "min output not satisfied");
        IMintable(elp).mint(_account, mintAmount);
        lastAddedAt[_account] = block.timestamp;
        IESBT(esbt).updateAddLiqScoreForAccount(_account, address(vault), usdxAmount.div(USDX_DECIMALS).mul(PRICE_PRECISION), 0);
        emit AddLiquidity(_account, _token, _amount, aumInUSD, elpSupply, usdxAmount, mintAmount); 
        return mintAmount;
    }

    function _addLiquidity(address _fundingAccount, address _account, address _token, uint256 _amount, uint256 _minUsdx, uint256 _minElp) private returns (uint256) {
        require(_fundingAccount != address(0), "zero address");
        require(_account != address(0), "ElpManager: zero address");
        require(_amount > 0, "ElpManager: invalid amount");
        // calculate aum before buyUSDX
        uint256 aumInUSD = getAumInUSD(true);
        uint256 elpSupply = IERC20(elp).totalSupply();
        IERC20(_token).safeTransferFrom(_fundingAccount, address(vault), _amount);
        uint256 usdxAmount = vault.buyUSDX(_token, address(this));
        require(usdxAmount >= _minUsdx, "buyin slippage Error");
        uint256 mintAmount = aumInUSD == 0 ? usdxAmount : usdxAmount.mul(elpSupply).div(aumInUSD);
        require(mintAmount >= _minElp, "min output not satisfied");
        IMintable(elp).mint(_account, mintAmount);
        lastAddedAt[_account] = block.timestamp;
        IESBT(esbt).updateAddLiqScoreForAccount(_account, address(vault), usdxAmount.div(USDX_DECIMALS).mul(PRICE_PRECISION), 0);
        emit AddLiquidity(_account, _token, _amount, aumInUSD, elpSupply, usdxAmount, mintAmount); 
        return mintAmount;
    }

    function removeLiquidity(address _tokenOut, uint256 _elpAmount, uint256 _minOut, address _receiver) external override nonReentrant returns (uint256) {
        if (inPrivateMode) { revert("ElpManager: action not enabled"); }
        return _removeLiquidity(msg.sender, _tokenOut, _elpAmount, _minOut, _receiver);
    }

    function _removeLiquidity(address _account, address _tokenOut, uint256 _elpAmount, uint256 _minOut, address _receiver) private returns (uint256) {
        require(_account != address(0), " transfer from the zero address");
        require(_elpAmount > 0, "ElpManager: invalid _elpAmount");
        require(lastAddedAt[_account].add(cooldownDuration) <= block.timestamp, "ElpManager: cooldown duration not yet passed");
        require(IERC20(elp).balanceOf(_account) >= _elpAmount, "insufficient ELP");
        // calculate aum before sellUSDX
        uint256 aumInUSD = getAumInUSD(false);
        uint256 elpSupply = IERC20(elp).totalSupply();
        uint256 usdxAmount = _elpAmount.mul(aumInUSD).div(elpSupply);
        IERC20(elp).safeTransferFrom(_account, address(this),_elpAmount );
        IMintable(elp).burn(address(this), _elpAmount);
        uint256 amountOut = vault.sellUSDX(_tokenOut, _receiver, usdxAmount);
        require(amountOut >= _minOut, "ElpManager: insufficient output");
        IESBT(esbt).updateAddLiqScoreForAccount(_account, address(vault), usdxAmount.div(USDX_DECIMALS).mul(PRICE_PRECISION), 100);
        emit RemoveLiquidity(_account, _tokenOut, _elpAmount, aumInUSD, elpSupply, usdxAmount, amountOut);

        return amountOut;
    }

    function removeLiquidityETH(uint256 _elpAmount) external nonReentrant payable returns (uint256) {
        if (inPrivateMode) { revert("ElpManager: action not enabled"); }
        address _account = msg.sender;
        require(_account != address(0), " transfer from the zero address");
        require(_elpAmount > 0, "ElpManager: invalid _elpAmount");
        require(lastAddedAt[_account].add(cooldownDuration) <= block.timestamp, "ElpManager: cooldown duration not yet passed");
        require(IERC20(elp).balanceOf(_account) >= _elpAmount, "insufficient ELP");
        address _tokenOut = weth;
        uint256 aumInUSDX = getAumInUSDX(false);
        uint256 elpSupply = IERC20(elp).totalSupply();
        uint256 usdxAmount = _elpAmount.mul(aumInUSDX).div(elpSupply);
        IERC20(elp).safeTransferFrom(_account, address(this),_elpAmount );
        IMintable(elp).burn(address(this), _elpAmount);
        uint256 _amountOut = vault.sellUSDX(_tokenOut, address(this), usdxAmount);
        IESBT(esbt).updateAddLiqScoreForAccount(_account, address(vault), usdxAmount.div(USDX_DECIMALS).mul(PRICE_PRECISION), 100);
        IWETH(weth).withdraw(_amountOut);
        payable(_account).sendValue(_amountOut);
        emit RemoveLiquidity(_account, _tokenOut, _elpAmount, aumInUSDX, elpSupply, usdxAmount, _amountOut);
        return _amountOut;
    }

    function getPoolInfo() public view returns (uint256[] memory) {
        uint256[] memory poolInfo = new uint256[](4);
        poolInfo[0] = getAum(true);
        poolInfo[1] = 0;//getAumSimple(true);
        poolInfo[2] = IERC20(elp).totalSupply();
        poolInfo[3] = IVault(vault).usdxSupply();
        return poolInfo;
    }


    function getPoolTokenList() public view returns (address[] memory) {
        return vault.fundingTokenList();
    }


    function getPoolTokenInfo(address _token) public view returns (uint256[] memory, int256[] memory) {
        // require(vault.whitelistedTokens(_token), "invalid token");
        // require(vault.isFundingToken(_token) || vault.isTradingToken(_token), "not )
        uint256[] memory tokenInfo_U= new uint256[](8);       
        int256[] memory tokenInfo_I = new int256[](4);       
        VaultMSData.TokenBase memory tBae = vault.getTokenBase(_token);
        VaultMSData.TradingFee memory tFee = vault.getTradingFee(_token);

        tokenInfo_U[0] = vault.totalTokenWeights() > 0 ? tBae.weight.mul(1000000).div(vault.totalTokenWeights()) : 0;
        tokenInfo_U[1] = tBae.poolAmount > 0 ? tBae.reservedAmount.mul(1000000).div(tBae.poolAmount) : 0;
        tokenInfo_U[2] = tBae.poolAmount;//vault.getTokenBalance(_token).sub(vault.feeReserves(_token)).add(vault.feeSold(_token));
        tokenInfo_U[3] = vault.getMaxPrice(_token);
        tokenInfo_U[4] = vault.getMinPrice(_token);
        tokenInfo_U[5] = tFee.fundingRatePerSec;
        tokenInfo_U[6] = tFee.accumulativefundingRateSec;
        tokenInfo_U[7] = tFee.latestUpdateTime;

        tokenInfo_I[0] = tFee.longRatePerSec;
        tokenInfo_I[1] = tFee.shortRatePerSec;
        tokenInfo_I[2] = tFee.accumulativeLongRateSec;
        tokenInfo_I[3] = tFee.accumulativeShortRateSec;

        return (tokenInfo_U, tokenInfo_I);
    }




    function getAums() public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = getAum(true);
        amounts[1] = getAum(false);
        return amounts;
    }

    function getAumInUSD(bool maximise) public view returns (uint256) {
        uint256 aum = getAum(maximise);
        return aum.mul(USDX_DECIMALS).div(PRICE_PRECISION);
    }

    function getAumInUSDX(bool maximise) public view returns (uint256) {
        uint256 aum = getAum(maximise);
        return aum.mul(USDX_DECIMALS).div(PRICE_PRECISION);
    }

    function getAum(bool maximise) public view returns (uint256) {
        address[] memory fundingTokenList = vault.fundingTokenList();
        address[] memory tradingTokenList = vault.tradingTokenList();
        uint256 aum = aumAddition;
        uint256 userShortProfits = 0;
        uint256 userLongProfits = 0;

        for (uint256 i = 0; i < fundingTokenList.length; i++) {
            address token = fundingTokenList[i];
            uint256 price = maximise ? vault.getMaxPrice(token) : vault.getMinPrice(token);
            VaultMSData.TokenBase memory tBae = vault.getTokenBase(token);
            uint256 poolAmount = tBae.poolAmount;
            uint256 decimals = vault.tokenDecimals(token);
            poolAmount = poolAmount.mul(price).div(10 ** decimals);
            poolAmount = poolAmount > vault.guaranteedUsd(token) ? poolAmount.sub(vault.guaranteedUsd(token)) : 0;
            aum = aum.add(poolAmount);
        }

        for (uint256 i = 0; i < tradingTokenList.length; i++) {
            address token = tradingTokenList[i];
            VaultMSData.TradingRec memory tradingRec = vault.getTradingRec(token);

            uint256 price = maximise ? vault.getMaxPrice(token) : vault.getMinPrice(token);
            uint256 shortSize = tradingRec.shortSize;
            if (shortSize > 0){
                uint256 averagePrice = tradingRec.shortAveragePrice;
                uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                uint256 delta = shortSize.mul(priceDelta).div(averagePrice);
                if (price > averagePrice) {
                    aum = aum.add(delta);
                } else {
                    userShortProfits = userShortProfits.add(delta);
                }    
            }

            uint256 longSize = tradingRec.longSize;
            if (longSize > 0){
                uint256 averagePrice = tradingRec.longAveragePrice;
                uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                uint256 delta = longSize.mul(priceDelta).div(averagePrice);
                if (price < averagePrice) {
                    aum = aum.add(delta);
                } else {
                    userLongProfits = userLongProfits.add(delta);
                }    
            }
        }

        uint256 _totalUserProfits = userLongProfits.add(userShortProfits);
        aum = _totalUserProfits > aum ? 0 : aum.sub(_totalUserProfits);
        return aumDeduction > aum ? 0 : aum.sub(aumDeduction);  
    }

/*
    function getWeightDetailed() public view returns (address[] memory, uint256[] memory) {
        uint256 length = vault.allWhitelistedTokensLength();
        uint256 aum = 0;
        uint256[] memory tokenAum = new uint256[](length);
        address[] memory tokenAddress = new address[](length);

        uint256 shortProfits = 0;

        for (uint256 i = 0; i < length; i++) {
            address token = vault.allWhitelistedTokens(i);
            bool isWhitelisted = vault.whitelistedTokens(token);

            if (!isWhitelisted) {
                continue;
            }

            uint256 price = vault.getMaxPrice(token);
            uint256 poolAmount = vault.poolAmounts(token);//.sub(vault.feeReserves(token)).add(vault.feeSold(token));
            uint256 decimals = vault.tokenDecimals(token);

            if (vault.stableTokens(token)) {
                uint256 _pA = poolAmount.mul(price).div(10 ** decimals);
                aum = aum.add(_pA);
                tokenAum[i] = tokenAum[i].add(_pA);
            } else {
                // add global short profit / loss
                uint256 size = vault.globalShortSizes(token);
                if (size > 0) {
                    uint256 averagePrice = vault.globalShortAveragePrices(token);
                    uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                    uint256 delta = size.mul(priceDelta).div(averagePrice);
                    if (price > averagePrice) {
                        // add losses from shorts
                        aum = aum.add(delta);
                        tokenAum[i] = tokenAum[i].add(delta);

                    } else {
                        shortProfits = shortProfits.add(delta);
                    }
                }

                aum = aum.add(vault.guaranteedUsd(token));
                tokenAum[i] = tokenAum[i].add(vault.guaranteedUsd(token));

                uint256 reservedAmount = vault.reservedAmounts(token);
                if (poolAmount > reservedAmount){
                    uint256 _mdfAmount = poolAmount.sub(reservedAmount).mul(price).div(10 ** decimals);
                    aum = aum.add(_mdfAmount);
                    tokenAum[i] = tokenAum[i].add(_mdfAmount);
                }

            }
        }

        for (uint256 i = 0; i < length; i++) {
            tokenAum[i] = aum > 0 ? tokenAum[i].mul(WEIGHT_PRECISSION).div(aum) : 0;
        }

        return (tokenAddress, tokenAum);
    }
*/

    function _validateHandler() private view {
        require(isHandler[msg.sender], "ElpManager: forbidden");
    }
}