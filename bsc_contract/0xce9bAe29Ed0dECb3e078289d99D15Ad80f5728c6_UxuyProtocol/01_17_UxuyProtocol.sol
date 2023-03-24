//SPDX-License-Identifier: UXUY
pragma solidity ^0.8.11;

import "./interfaces/IProtocol.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/IBridge.sol";
import "./libraries/BrokerBase.sol";
import "./libraries/SafeNativeAsset.sol";
import "./libraries/SafeERC20.sol";

contract UxuyProtocol is IProtocol, CommonBase {
    using SafeNativeAsset for address;
    using SafeERC20 for IERC20;

    struct TradeState {
        address tokenIn;
        address tokenOut;
        int feeTokenIndex;
        address feeToken;
        uint feeAmount;
        uint feeShareAmount;
        uint extraFeeAmount;
        address nextRecipient;
    }

    // zero address
    address internal constant NULL_ADDRESS = address(0);

    // fee rate denominator
    uint private constant FEE_DENOMINATOR = 1e6;

    // swap contract
    ISwap private _swapContract;

    // bridge contract
    IBridge private _bridgeContract;

    // total fee rate in 1/FEE_DENOMINATOR
    uint private _feeRate;

    // fee share rate in 1/FEE_DENOMINATOR
    uint private _feeShareRate;

    // recipient address to receive fee in main tokens
    address private _mainFeeRecipient;

    // recipient address to receive fee in other tokens
    address private _altFeeRecipient;

    // free of charge accounts
    mapping(address => bool) private _focAccounts;

    // main tokens for fee charging
    mapping(address => bool) private _mainFeeTokens;

    // @dev Emitted when fee recipient is updated by owner
    event FeeRecipientChanged(address main, address alt);

    // @dev Emitted when FOC account is updated by owner
    event FOCAccountChanged(address account, bool foc);

    // @dev Emitted when fee token is updated by owner
    event FeeTokenChanged(address token, bool main);

    // @param swapContract_ the Swap contract address
    // @param bridgeContract_ the Bridge contract address
    // @param feeRate_ the total fee rate
    // @param feeShareRate_ the fee share rate
    // @param mainFeeRecipient_ the account to receive fee in main tokens
    // @param altFeeRecipient_ the account to receive fee in other tokens
    constructor(
        address swapContract_,
        address bridgeContract_,
        uint feeRate_,
        uint feeShareRate_,
        address mainFeeRecipient_,
        address altFeeRecipient_
    ) {
        _swapContract = ISwap(swapContract_);
        _bridgeContract = IBridge(bridgeContract_);
        _setFeeRate(feeRate_, feeShareRate_);
        _setFeeRecipient(mainFeeRecipient_, altFeeRecipient_);
    }

    function swapContract() external view override returns (address) {
        return address(_swapContract);
    }

    function bridgeContract() external view override returns (address) {
        return address(_bridgeContract);
    }

    function feeDenominator() external pure returns (uint) {
        return FEE_DENOMINATOR;
    }

    function feeRate() external view returns (uint) {
        return _feeRate;
    }

    function feeShareRate() external view returns (uint) {
        return _feeShareRate;
    }

    // @dev changes the swap and bridge contract addresses
    function setContract(address swapContract_, address bridgeContract_) external onlyOwner {
        require(
            swapContract_ != NULL_ADDRESS && bridgeContract_ != NULL_ADDRESS,
            "UxuyProtocol: invalid contract address"
        );
        _swapContract = ISwap(swapContract_);
        _bridgeContract = IBridge(bridgeContract_);
    }

    // @dev changes the fee rate
    function setFeeRate(uint feeRate_, uint feeShareRate_) external onlyOwner {
        _setFeeRate(feeRate_, feeShareRate_);
    }

    // @dev changes the fee recipients
    function setFeeRecipient(address main, address alt) external onlyOwner {
        _setFeeRecipient(main, alt);
    }

    // @dev updates free of charge accounts
    function updateFOCAccounts(address[] memory accounts, bool foc) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            if (foc) {
                _focAccounts[accounts[i]] = true;
            } else {
                delete _focAccounts[accounts[i]];
            }
            emit FOCAccountChanged(accounts[i], foc);
        }
    }

    // @dev changes the token accept status
    function updateFeeTokens(address[] memory tokens, bool main) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            if (main) {
                _mainFeeTokens[tokens[i]] = true;
            } else {
                delete _mainFeeTokens[tokens[i]];
            }
            emit FeeTokenChanged(tokens[i], main);
        }
    }

    function trade(
        TradeParams calldata params
    )
        external
        payable
        whenNotPaused
        noDelegateCall
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint amountOut, uint bridgeTxnID)
    {
        TradeState memory state;
        if (params.swaps.length > 0) {
            for (uint i = 0; i < params.swaps.length; i++) {
                require(
                    _swapContract.getProvider(params.swaps[i].providerID) != NULL_ADDRESS,
                    "UxuyProtocol: invalid swap provider"
                );
            }
            state.tokenIn = params.swaps[0].path[0];
            state.nextRecipient = _swapContract.getProvider(params.swaps[0].providerID);
        } else {
            state.tokenIn = params.bridge.tokenIn;
            state.nextRecipient = _bridgeContract.getProvider(params.bridge.providerID);
        }
        if (params.bridge.providerID == 0) {
            state.tokenOut = _tokenOut(params.swaps[params.swaps.length - 1].path);
        } else {
            require(
                _bridgeContract.getProvider(params.bridge.providerID) != NULL_ADDRESS,
                "UxuyProtocol: invalid bridge provider"
            );
            state.tokenOut = params.bridge.tokenOut;
        }
        if (state.tokenIn.isNativeAsset()) {
            require(msg.value >= params.amountIn, "UxuyProtocol: not enough ETH in transaction");
            amountOut = msg.value;
        } else {
            require(
                IERC20(state.tokenIn).balanceOf(_msgSender()) >= params.amountIn,
                "UxuyProtocol: sender token balance is not enough"
            );
            require(
                IERC20(state.tokenIn).allowance(_msgSender(), address(this)) >= params.amountIn,
                "UxuyProtocol: token allowance is not enough"
            );
            amountOut = params.amountIn;
        }
        if (params.extraFeeAmountIn > 0) {
            require(amountOut > params.extraFeeAmountIn, "UxuyProtocol: not enough amount for extra fee");
            state.extraFeeAmount = _payExtraFee(state.tokenIn, params.extraFeeAmountIn, params.extraFeeSwaps);
            amountOut -= params.extraFeeAmountIn;
        }
        state.feeTokenIndex = _findFeeToken(params.swaps);
        state.feeToken = NULL_ADDRESS;
        state.feeAmount = 0;
        state.feeShareAmount = 0;
        if (state.feeTokenIndex == 0) {
            state.feeToken = state.tokenIn;
            (amountOut, state.feeAmount, state.feeShareAmount) = _payFee(
                state.tokenIn.isNativeAsset() ? address(this) : _msgSender(),
                state.feeToken,
                amountOut,
                params.feeShareRecipient
            );
        }
        if (state.tokenIn.isNativeAsset()) {
            state.nextRecipient.safeTransfer(amountOut);
        } else {
            uint balanceBefore = IERC20(state.tokenIn).balanceOf(state.nextRecipient);
            IERC20(state.tokenIn).safeTransferFrom(_msgSender(), state.nextRecipient, amountOut);
            amountOut = IERC20(state.tokenIn).balanceOf(state.nextRecipient) - balanceBefore;
        }
        for (uint i = 0; i < params.swaps.length; i++) {
            SwapParams calldata swap = params.swaps[i];
            if (i + 1 < params.swaps.length) {
                state.nextRecipient = _swapContract.getProvider(params.swaps[i + 1].providerID);
            } else if (params.bridge.providerID != 0) {
                state.nextRecipient = _bridgeContract.getProvider(params.bridge.providerID);
            } else {
                state.nextRecipient = params.recipient;
            }
            amountOut = _swapContract.swap(
                ISwap.SwapParams({
                    providerID: swap.providerID,
                    path: swap.path,
                    amountIn: amountOut,
                    minAmountOut: swap.minAmountOut,
                    recipient: (state.feeTokenIndex == int(i + 1)) ? address(this) : state.nextRecipient,
                    data: swap.data
                })
            );
            if (state.feeTokenIndex == int(i + 1)) {
                state.feeToken = _tokenOut(swap.path);
                (amountOut, state.feeAmount, state.feeShareAmount) = _payFee(
                    address(this),
                    state.feeToken,
                    amountOut,
                    params.feeShareRecipient
                );
                require(amountOut >= swap.minAmountOut, "UxuyProtocol: amount less than minAmountOut");
                uint balanceBefore = 0;
                if (!state.feeToken.isNativeAsset()) {
                    balanceBefore = IERC20(state.feeToken).balanceOf(state.nextRecipient);
                }
                _safeTransfer(address(this), state.feeToken, amountOut, state.nextRecipient);
                if (!state.feeToken.isNativeAsset()) {
                    // handle token with supporting fee on transfer
                    amountOut = IERC20(state.feeToken).balanceOf(state.nextRecipient) - balanceBefore;
                }
            }
        }
        bridgeTxnID = 0;
        if (params.bridge.providerID != 0) {
            BridgeParams calldata bridge = params.bridge;
            (amountOut, bridgeTxnID) = _bridgeContract.bridge(
                IBridge.BridgeParams({
                    providerID: bridge.providerID,
                    tokenIn: bridge.tokenIn,
                    chainIDOut: bridge.chainIDOut,
                    tokenOut: bridge.tokenOut,
                    amountIn: amountOut,
                    minAmountOut: bridge.minAmountOut,
                    recipient: params.recipient,
                    data: bridge.data
                })
            );
        }
        emit Traded(
            _msgSender(),
            params.recipient,
            params.feeShareRecipient,
            state.tokenIn,
            params.amountIn,
            params.bridge.chainIDOut,
            state.tokenOut,
            amountOut,
            bridgeTxnID,
            state.feeToken,
            state.feeAmount,
            state.feeShareAmount,
            state.extraFeeAmount
        );
    }

    function _setFeeRate(uint feeRate_, uint feeShareRate_) internal {
        require(feeRate_ >= feeShareRate_, "UxuyProtocol: fee share rate is less than total fee rate");
        _feeRate = feeRate_;
        _feeShareRate = feeShareRate_;
        emit FeeRateChanged(_feeRate, _feeShareRate);
    }

    function _setFeeRecipient(address main, address alt) internal {
        require(main != NULL_ADDRESS && alt != NULL_ADDRESS, "UxuyProtocol: fee recipient is null");
        _mainFeeRecipient = main;
        _altFeeRecipient = alt;
        emit FeeRecipientChanged(_mainFeeRecipient, _altFeeRecipient);
    }

    // @dev find token to pay fee.
    // @return feeTokenIndex the index of token to pay fee:
    //         feeTokenIndex < 0: no need to pay fee;
    //         feeTokenIndex == 0: use first input token;
    //         feeTokenIndex > 0: use the output token of the swapList[feeTokenIndex-1].
    function _findFeeToken(SwapParams[] calldata swaps) internal view returns (int) {
        if (!_needPayFee()) {
            return -1;
        }
        if (swaps.length == 0) {
            return 0;
        }
        address tokenIn = swaps[0].path[0];
        if (tokenIn.isNativeAsset() || _mainFeeTokens[tokenIn]) {
            return 0;
        }
        for (uint i = 0; i < swaps.length; i++) {
            address tokenOut = swaps[i].path[swaps[i].path.length - 1];
            if (tokenOut.isNativeAsset() || _mainFeeTokens[tokenOut]) {
                return int(i + 1);
            }
        }
        return 0;
    }

    function _payExtraFee(
        address tokenIn,
        uint amountIn,
        SwapParams[] calldata swaps
    ) internal returns (uint extraFeeAmount) {
        address nextRecipient;
        if (swaps.length == 0) {
            nextRecipient = _msgSender();
        } else {
            nextRecipient = _swapContract.getProvider(swaps[0].providerID);
        }
        if (tokenIn.isNativeAsset()) {
            nextRecipient.safeTransfer(amountIn);
        } else {
            if (nextRecipient != _msgSender()) {
                uint balanceBefore = IERC20(tokenIn).balanceOf(nextRecipient);
                IERC20(tokenIn).safeTransferFrom(_msgSender(), nextRecipient, amountIn);
                amountIn = IERC20(tokenIn).balanceOf(nextRecipient) - balanceBefore;
            }
        }
        for (uint i = 0; i < swaps.length; i++) {
            SwapParams calldata swap = swaps[i];
            if (i + 1 < swaps.length) {
                nextRecipient = _swapContract.getProvider(swaps[i + 1].providerID);
            } else {
                nextRecipient = _msgSender();
            }
            amountIn = _swapContract.swap(
                ISwap.SwapParams({
                    providerID: swap.providerID,
                    path: swap.path,
                    amountIn: amountIn,
                    minAmountOut: swap.minAmountOut,
                    recipient: nextRecipient,
                    data: swap.data
                })
            );
        }
        return amountIn;
    }

    function _payFee(
        address sender,
        address token,
        uint amount,
        address feeShareRecipient
    ) internal returns (uint amountLeft, uint feeAmount, uint feeShareAmount) {
        if (!_needPayFee()) {
            return (amount, 0, 0);
        }
        feeAmount = (amount * _feeRate) / FEE_DENOMINATOR;
        require(feeAmount > 0, "UxuyProtocol: fee amount is zero");
        feeShareAmount = 0;
        uint feeLeftAmount = feeAmount;
        if (feeShareRecipient != NULL_ADDRESS) {
            feeShareAmount = (amount * _feeShareRate) / FEE_DENOMINATOR;
            require(feeShareAmount > 0, "UxuyProtocol: fee share amount is zero");
            _safeTransfer(sender, token, feeShareAmount, feeShareRecipient);
            feeLeftAmount -= feeShareAmount;
        }
        address feeRecipient = (token.isNativeAsset() || _mainFeeTokens[token]) ? _mainFeeRecipient : _altFeeRecipient;
        _safeTransfer(sender, token, feeLeftAmount, feeRecipient);
        return (amount - feeAmount, feeAmount, feeShareAmount);
    }

    function _needPayFee() internal view returns (bool) {
        return
            _feeRate > 0 &&
            !_focAccounts[_msgSender()] &&
            _msgSender() != _mainFeeRecipient &&
            _msgSender() != _altFeeRecipient;
    }

    function _safeTransfer(address sender, address token, uint amount, address recipient) internal {
        if (token.isNativeAsset()) {
            recipient.safeTransfer(amount);
        } else if (sender == address(this)) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            IERC20(token).safeTransferFrom(sender, recipient, amount);
        }
    }

    function _tokenOut(address[] calldata path) internal pure returns (address) {
        return path[path.length - 1];
    }
}