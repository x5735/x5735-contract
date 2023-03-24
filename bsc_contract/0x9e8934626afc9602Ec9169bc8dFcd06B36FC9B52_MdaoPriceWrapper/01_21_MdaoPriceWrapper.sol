// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./contracts/token/ERC20/utils/SafeERC20.sol";
import "./contracts/access/Ownable.sol";
import "./contracts/security/ReentrancyGuard.sol";
import "./contracts/pancake/IPancakePair.sol";
import "./contracts/pancake/IPancakeFactory.sol";
import "./MdaoVoucherNFT.sol";

interface Metadata {
    function decimals() external view returns (uint8);
}

interface IMdaoPriceWrapper {
    enum VestingType { OneTime, Linear, Stages }

    function mintWrappedNft(
        address[] memory tokenList,
        uint256[] memory amountsList,
        uint256[] memory stagesShares,
        uint256[] memory stagesPrices,
        VestingType vestingType,
        address[] memory pair,
        bool withdrawWithPenalty
    ) external;
    function chargeWrappedNft(uint256 uid, uint256[] memory amountsList) external;
    function claim(uint256 uid) external;
    function withdrawWithPenalty(uint256 uid) external;

    function setWithdrawFee(uint256 withdrawFee) external;
    function setFeeAddress(address feeAddress) external;
    function cancelNFTOwnership() external;

    function getOneTokenPrice(uint256 uid) external returns (uint256);
    function totalVoucherMinted() external returns (uint256);
    function viewTokenListById(uint256 uid) external returns (address[] memory);
    function viewAmountListById(uint256 uid) external returns (uint256[] memory);
    function viewStagesPricesById(uint256 uid) external returns (uint256[] memory);
    function viewStageSharesById(uint256 uid) external returns (uint256[] memory);

    event MintWrappedNft(uint256 uid);
    event ChargeWrappedNft(uint256 uid);
    event Claim(uint256 uid, uint256 shareToPay);
    event WithdrawWithPenalty(uint256 uid, uint256 shareToPay);
    event SetWithdrawFee(uint256 withdrawFee);
    event SetFeeAddress(address feeAddress);
}

contract MdaoPriceWrapper is IMdaoPriceWrapper, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct TargetTokenPair {
        uint8 decimals;
        address baseToken;
        address pairAddress;
    }
    
    struct Voucher {
        uint256 tokenId;
        TargetTokenPair tokenPair;
        uint256 unlockStartPrice;
        uint256 unlockEndPrice;
        uint256 fundsLeft; // 10000 (100%)
        uint256[] stagesShares;
        uint256[] stagesPrices;
        uint256[] amountsList;
        address[] tokenList;
        VestingType vestingType; // OneTime, Linear, Staged
        bool withdrawWithPenalty;
        bool ended;
    }

    uint256 public constant PERCENT_DENOMINATOR = 10000;
    uint256 public constant MAX_WITHDRAWAL_FEE = 100 ether; // in tokens
    uint256 public constant PENALTY = 2000;

    IPancakeFactory public pancakeFactory;

    IERC20 public mdaoToken;
    MdaoVoucherNFT public nftContract;
    address public feeAddress;
    uint256 public withdrawFee;

    Voucher[] public vouchers;

    constructor(IERC20 _mdaoToken, MdaoVoucherNFT _nftContract, address _feeAddress, uint256 _withdrawFee, address _pancakeFactory) {
        require(_feeAddress != address(0), "feeAddress can be address(0)");

        mdaoToken = _mdaoToken;
        nftContract = _nftContract;
        feeAddress = _feeAddress;
        withdrawFee = _withdrawFee;
        pancakeFactory = IPancakeFactory(_pancakeFactory);
    }

    modifier correctUID(uint256 _uid) {
        require(_uid < vouchers.length, "bad uid");
        require(nftContract.ownerOf(vouchers[_uid].tokenId) == msg.sender, "wrong owner");
        require(vouchers[_uid].ended == false, "pool not live");
        _;
    }

    modifier correctMintParams(
        address[] memory _tokenList,
        uint256[] memory _amountsList,
        uint256[] memory _stagesShares,
        uint256[] memory _stagesPrices,
        address[] memory _pair,
        VestingType _vestingType
    ) {
        require(0 < _tokenList.length && _tokenList.length < 50, "wrong tokenList length");
        require(_tokenList.length == _amountsList.length, "wrong array length");

        require(_pair.length == 2, "wrong pair length");

        if (_vestingType == VestingType.Stages) {
            require(1 < _stagesPrices.length && _stagesPrices.length < 50, "wrong prices array length");
            require(_stagesShares.length == _stagesPrices.length, "wrong stages array length");
            require(calculateShares(_stagesShares), "wrong total shares");

            for (uint256 i = 1; i < _stagesPrices.length; i++) {
                require(_stagesPrices[i - 1] <= _stagesPrices[i], "wrong price order");
            }
        } else if (_vestingType == VestingType.Linear) {
            require(_stagesShares.length == 0, "wrong stages array length");
            require(_stagesPrices.length == 2, "wrong prices array length");
            require(_stagesPrices[0] <= _stagesPrices[1], "wrong price order");
        } else if (_vestingType == VestingType.OneTime) {
            require(_stagesShares.length == 0, "wrong stages array length");
            require(_stagesPrices.length == 1, "wrong prices array length");
        }
        _;
    }

    modifier correctChargeParams(uint256 _uid, uint256[] memory _amountsList) {
        require(vouchers[_uid].tokenList.length == _amountsList.length, "chargeWrappedNft: wrong amounts");
        require(vouchers[_uid].fundsLeft == PERCENT_DENOMINATOR, "chargeWrappedNft: pool isn't full");
        _;
    }

    modifier correctOneTimeClaim(uint256 _uid) {
        require(getOneTokenPrice(_uid) >= vouchers[_uid].unlockEndPrice, "claim: too early");
        _;
    }

    modifier correctWithdrawWithPenalty(uint256 _uid) {
        require(vouchers[_uid].ended == false, "pool not live");
        require(vouchers[_uid].withdrawWithPenalty, "not alowed");
        _;
    }

    /// This pair not found. Needed pair
    /// created by `supportedPancakeFactory` supportedPancakeFactory.
    /// @param supportedPancakeFactory address of supported Pancake Factory.
    error PairNotFound(address supportedPancakeFactory);

    function mintWrappedNft(
        address[] memory _tokenList,
        uint256[] memory _amountsList,
        uint256[] memory _stagesShares, // Staged, total 100% (10000)
        uint256[] memory _stagesPrices, // first = start, last = end
        VestingType _vestingType,       // OneTime, Linear, Staged
        address[] memory _pair,         // first = baseToken, second = quoteToken
        bool _withdrawWithPenalty
    ) external nonReentrant correctMintParams(
        _tokenList,
        _amountsList,
        _stagesShares,
        _stagesPrices,
        _pair,
        _vestingType
    ) {
        vouchers.push(Voucher(
            nftContract.mint(msg.sender),
            getTokenPair(_pair[0], _pair[1]),
            (_vestingType == VestingType.OneTime) ? 0 : _stagesPrices[0],
            _stagesPrices[_stagesPrices.length - 1],
            PERCENT_DENOMINATOR,
            _stagesShares,
            _stagesPrices,
            _amountsList,            
            _tokenList,
            _vestingType,
            _withdrawWithPenalty,
            false
        ));

        depositERC20List(_tokenList, _amountsList, false, 0);
        emit MintWrappedNft(totalVoucherMinted() - 1);
    }

    function chargeWrappedNft(uint256 _uid, uint256[] memory _amountsList) external nonReentrant correctUID(_uid) correctChargeParams(_uid, _amountsList) {
        depositERC20List(vouchers[_uid].tokenList, _amountsList, true, _uid);
        emit ChargeWrappedNft(_uid);
    }

    function claim(uint256 _uid) external nonReentrant correctUID(_uid) {
        Voucher memory voucher = vouchers[_uid];

        uint256 shareToPay;

        if (voucher.vestingType == VestingType.OneTime) shareToPay = claimOneTime(_uid);
        else if (voucher.vestingType == VestingType.Linear) shareToPay = claimLinear(_uid);
        else if (voucher.vestingType == VestingType.Stages) shareToPay = claimStages(_uid);

        if (shareToPay > 0) payWithdrawalFee(shareToPay);
        if (vouchers[_uid].fundsLeft == 0) burnWrappedNft(_uid);

        emit Claim(_uid, shareToPay);
    }

    function withdrawWithPenalty(uint256 _uid) external nonReentrant correctUID(_uid) correctWithdrawWithPenalty(_uid) {
        Voucher memory voucher = vouchers[_uid];
        uint256 shareToPay = voucher.fundsLeft;

        burnWrappedNft(_uid);

        if (shareToPay > 0) {
            withdrawERC20ListWithPenalty(voucher.tokenList, voucher.amountsList, shareToPay);
            payWithdrawalFee(shareToPay);
            vouchers[_uid].fundsLeft = 0;
        }

        emit WithdrawWithPenalty(_uid, shareToPay);
    }

    function getOneTokenPrice(uint256 _uid) public view returns (uint256) {
        return getTokenPrice(vouchers[_uid].tokenPair);
    }

    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        require(_withdrawFee <= MAX_WITHDRAWAL_FEE, "wrong fee");
        withdrawFee = _withdrawFee;

        emit SetWithdrawFee(_withdrawFee);
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "feeAddress can be address(0)");
        feeAddress = _feeAddress;

        emit SetFeeAddress(_feeAddress);
    }

    function cancelNFTOwnership() external onlyOwner {
        nftContract.transferOwnership(owner());
    }

    // INTERNAL FUNCTIONS
    function getTokenPair(address _baseToken, address _quoteToken) internal view returns (TargetTokenPair memory) {
        address pairAddress = pancakeFactory.getPair(_baseToken, _quoteToken);
        if (pairAddress == address(0)) {
            revert PairNotFound(address(pancakeFactory));
        }

        return TargetTokenPair(
            Metadata(_baseToken).decimals(),
            _baseToken,
            pairAddress
        );
    }

    function getTokenPrice(TargetTokenPair memory _tokenPair) internal view returns (uint256) {
        IPancakePair pair = IPancakePair(_tokenPair.pairAddress);
        (uint112 reserves0, uint112 reserves1, ) = pair.getReserves();
        (uint112 reserveBase, uint112 reserveQuote) = pair.token0() ==
            address(_tokenPair.baseToken)
            ? (reserves0, reserves1)
            : (reserves1, reserves0);

        if (reserveBase > 0) {
            uint256 oneToken = 10**(_tokenPair.decimals);
            return (oneToken * reserveQuote) / reserveBase + 1;
        } else {
            return 1;
        }
    }

    function calculateShares(uint256[] memory _stagesShares) internal pure returns (bool) {
        uint256 totalSum;
        for (uint256 index = 0; index < _stagesShares.length; index++) {
            totalSum += _stagesShares[index];
        }
        return totalSum == PERCENT_DENOMINATOR;
    }

    function depositERC20List(address[] memory _tokenList, uint256[] memory _amountsList, bool _updatePool, uint256 _uid) internal {
        for (uint256 index = 0; index < _tokenList.length; index++) {
            if (_amountsList[index] > 0) {
                uint256 balanceBefore = IERC20(_tokenList[index]).balanceOf(address(this));
                IERC20(_tokenList[index]).safeTransferFrom(msg.sender, address(this), _amountsList[index]);

                // Support txfee tokens or partial withdraw for prevent failed withdrawals
                if (_updatePool) vouchers[_uid].amountsList[index] = vouchers[_uid].amountsList[index]
                    + IERC20(_tokenList[index]).balanceOf(address(this)) - balanceBefore;
                _amountsList[index] = IERC20(_tokenList[index]).balanceOf(address(this)) - balanceBefore;
            }
        }
    }

    function claimOneTime(uint256 _uid) internal correctOneTimeClaim(_uid) returns(uint256) {
        Voucher memory voucher = vouchers[_uid];

        withdrawERC20List(voucher.tokenList, voucher.amountsList, PERCENT_DENOMINATOR);
        vouchers[_uid].fundsLeft = 0;

        return PERCENT_DENOMINATOR;
    }

    function claimLinear(uint256 _uid) internal returns(uint256) {
        Voucher memory voucher = vouchers[_uid];

        uint256 currentPrice = getOneTokenPrice(_uid);
        require(currentPrice > voucher.unlockStartPrice, "claim: too early");

        uint256 priceToCalculate = currentPrice < voucher.unlockEndPrice ? currentPrice : voucher.unlockEndPrice;
        uint256 shareToPay = voucher.fundsLeft
            * (priceToCalculate - voucher.unlockStartPrice)
            / (voucher.unlockEndPrice - voucher.unlockStartPrice);

        if (shareToPay > 0) {
            vouchers[_uid].fundsLeft = voucher.fundsLeft - shareToPay;
            withdrawERC20List(voucher.tokenList, voucher.amountsList, shareToPay);
            vouchers[_uid].unlockStartPrice = currentPrice;
        }

        return shareToPay;
    }

    function claimStages(uint256 _uid) internal returns(uint256) {
        Voucher memory voucher = vouchers[_uid];

        uint256 currentPrice = getOneTokenPrice(_uid);
        uint256 shareToPaySum;

        for (uint256 stageId = 0; stageId < voucher.stagesPrices.length; stageId++) {
            if (voucher.stagesPrices[stageId] != 0 && currentPrice >= voucher.stagesPrices[stageId]) {
                shareToPaySum = shareToPaySum + voucher.stagesShares[stageId];
                vouchers[_uid].stagesPrices[stageId] = 0;
            }
        }

        if (shareToPaySum > 0) {
            vouchers[_uid].fundsLeft = voucher.fundsLeft - shareToPaySum;
            withdrawERC20List(voucher.tokenList, voucher.amountsList, shareToPaySum);
        }

        return shareToPaySum;
    }

    function withdrawERC20List(address[] memory _tokenList, uint256[] memory _amountsList, uint256 _share) internal {
        for (uint256 index = 0; index < _tokenList.length; index++) {
            uint256 amount = _amountsList[index] * _share / PERCENT_DENOMINATOR;
            IERC20(_tokenList[index]).safeTransfer(msg.sender, amount);
        }
    }

    function payWithdrawalFee(uint256 _share) internal {
        uint256 amountToPay = withdrawFee * _share / PERCENT_DENOMINATOR;
        mdaoToken.safeTransferFrom(msg.sender, feeAddress, amountToPay);
    }

    function withdrawERC20ListWithPenalty(address[] memory _tokenList, uint256[] memory _amountsList, uint256 _share) internal {
        for (uint256 index = 0; index < _tokenList.length; index++) {
            uint256 amount = _amountsList[index] * _share / PERCENT_DENOMINATOR;
            uint256 penalty = amount * PENALTY / PERCENT_DENOMINATOR;

            IERC20(_tokenList[index]).safeTransfer(msg.sender, amount - penalty);
            IERC20(_tokenList[index]).safeTransfer(feeAddress, penalty);
        }
    }

    function burnWrappedNft(uint256 _uid) internal {
        nftContract.burn(vouchers[_uid].tokenId);
        vouchers[_uid].ended = true;
    }

    // VIEW FUNCTIONS
    function totalVoucherMinted() public view returns (uint256) {
        return vouchers.length;
    }

    function viewTokenListById(uint256 _uid) public view returns (address[] memory) {
        return vouchers[_uid].tokenList;
    }

    function viewAmountListById(uint256 _uid) public view returns (uint256[] memory) {
        return vouchers[_uid].amountsList;
    }

    function viewStagesPricesById(uint256 _uid) public view returns (uint256[] memory) {
        return vouchers[_uid].stagesPrices;
    }

    function viewStageSharesById(uint256 _uid) public view returns (uint256[] memory) {
        return vouchers[_uid].stagesShares;
    }
}