// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./contracts/token/ERC20/utils/SafeERC20.sol";
import "./contracts/access/Ownable.sol";
import "./contracts/security/ReentrancyGuard.sol";
import "./MdaoVoucherNFT.sol";

interface IMdaoTimeWrapper {
    enum VestingType { OneTime, Linear, Stages }

    function mintWrappedNft(
        address[] memory tokenList,
        uint256[] memory amountsList,
        uint256[] memory stagesShares,
        uint256[] memory stagesDates,
        VestingType vestingType,
        bool withdrawWithPenalty
    ) external;
    function chargeWrappedNft(uint256 uid, uint256[] memory amountsList) external;
    function claim(uint256 uid) external;
    function withdrawWithPenalty(uint256 uid) external;

    function setWithdrawFee(uint256 withdrawFee) external;
    function setFeeAddress(address feeAddress) external;
    function cancelNFTOwnership() external;

    function totalVoucherMinted() external view returns (uint256);
    function viewTokenListById(uint256 uid) external view returns (address[] memory);
    function viewAmountListById(uint256 uid) external view returns (uint256[] memory);
    function viewStageDatesById(uint256 uid) external view returns (uint256[] memory);
    function viewStageSharesById(uint256 uid) external view returns (uint256[] memory);

    event MintWrappedNft(uint256 uid);
    event ChargeWrappedNft(uint256 uid);
    event Claim(uint256 uid, uint256 shareToPay);
    event WithdrawWithPenalty(uint256 uid, uint256 shareToPay);
    event SetWithdrawFee(uint256 withdrawFee);
    event SetFeeAddress(address feeAddress);
}

contract MdaoTimeWrapper is IMdaoTimeWrapper, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Voucher {
        uint256 tokenId;
        uint256 unlockStartTimestamp;
        uint256 unlockEndTimestamp;
        uint256 fundsLeft; // 10000 (100%)
        uint256[] amountsList;
        uint256[] stagesShares;
        uint256[] stagesDates;
        address[] tokenList;
        VestingType vestingType; // OneTime, Linear, Staged
        bool withdrawWithPenalty;
        bool ended;
    }

    uint256 public constant PERCENT_DENOMINATOR = 10000;
    uint256 public constant MAX_WITHDRAWAL_FEE = 100 ether; // in tokens
    uint256 public constant PENALTY = 2000;

    IERC20 public mdaoToken;
    MdaoVoucherNFT public nftContract;
    address public feeAddress;
    uint256 public withdrawalFee;

    Voucher[] public vouchers;

    constructor(IERC20 _mdaoToken, MdaoVoucherNFT _nftContract, address _feeAddress, uint256 _withdrawalFee) {
        mdaoToken = _mdaoToken;
        nftContract = _nftContract;
        feeAddress = _feeAddress;
        withdrawalFee = _withdrawalFee;
    }

    modifier isEOA() {
        require(
            address(msg.sender).code.length == 0 && msg.sender == tx.origin,
            "Only for human"
        );
        _;
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
        uint256[] memory _stagesDates,
        VestingType _vestingType
    ) {
        require(0 < _tokenList.length && _tokenList.length < 50, "wrong tokenList length");
        require(_tokenList.length == _amountsList.length, "wrong array length");
        
        if (_vestingType == VestingType.Stages) {
            require(1 < _stagesDates.length && _stagesDates.length < 50, "wrong dates array length");
            require(_stagesShares.length == _stagesDates.length, "wrong stages array length");
            require(calculateShares(_stagesShares), "wrong total shares");

            for (uint256 i = 0; i < _stagesDates.length; i++) {
                require(0 < _stagesDates[i] && _stagesDates[i] < 2524608000, "wrong date order"); // 2524608000 - Jan 1, 2050
            }

            for (uint256 i = 1; i < _stagesDates.length; i++) {
                require(_stagesDates[i - 1] <= _stagesDates[i], "wrong date order");
            }
        } else if (_vestingType == VestingType.Linear) {
            require(_stagesShares.length == 0, "wrong stages array length");
            require(_stagesDates.length == 2, "wrong prices array length");
            require(_stagesDates[0] <= _stagesDates[1], "wrong price order");
        } else if (_vestingType == VestingType.OneTime) {
            require(_stagesShares.length == 0, "wrong stages array length");
            require(_stagesDates.length == 1, "wrong prices array length");
        }
        _;
    }

    modifier correctChargeParams(uint256 _uid, uint256[] memory _amountsList) {
        require(vouchers[_uid].tokenList.length == _amountsList.length, "depositToNft: wrong amounts");
        require(vouchers[_uid].fundsLeft == PERCENT_DENOMINATOR, "chargeWrappedNft: pool isn't full");
        _;
    }

    modifier correctOneTimeClaim(uint256 _uid) {
        require(block.timestamp >= vouchers[_uid].unlockEndTimestamp, "claim: too early");
        _;
    }

    modifier correctLinearClaim(uint256 _uid) {
        require(block.timestamp >= vouchers[_uid].unlockStartTimestamp, "claim: too early");
        _;
    }

    modifier correctWithdrawWithPenalty(uint256 _uid) {
        require(vouchers[_uid].withdrawWithPenalty, "not alowed");
        _;
    }

    function mintWrappedNft(
        address[] memory _tokenList,
        uint256[] memory _amountsList,
        uint256[] memory _stagesShares, // Staged, total 100% (10000)
        uint256[] memory _stagesDates,  // first date = start, last date = end
        VestingType _vestingType,       // OneTime, Linear, Staged
        bool _withdrawWithPenalty
    ) external nonReentrant correctMintParams(
        _tokenList,
        _amountsList,
        _stagesShares,
        _stagesDates,
        _vestingType
    ) {
        uint256 tokenId = nftContract.mint(msg.sender);

        vouchers.push(Voucher(
            tokenId,
            (_vestingType == VestingType.OneTime) ? 0 : _stagesDates[0],
            _stagesDates[_stagesDates.length - 1],
            PERCENT_DENOMINATOR,
            _amountsList,
            _stagesShares,
            _stagesDates,
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

    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        require(_withdrawFee <= MAX_WITHDRAWAL_FEE, "wrong fee");
        withdrawalFee = _withdrawFee;

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
    function calculateShares(uint256[] memory _stagesShares) internal pure returns (bool) {
        uint256 totalSum;
        for (uint index = 0; index < _stagesShares.length; index++) {
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

    function claimLinear(uint256 _uid) internal correctLinearClaim(_uid) returns(uint256) {
        Voucher memory voucher = vouchers[_uid];

        uint256 timeToCalculate = block.timestamp < voucher.unlockEndTimestamp ? block.timestamp : voucher.unlockEndTimestamp;
        uint256 shareToPay = voucher.fundsLeft
            * (timeToCalculate - voucher.unlockStartTimestamp)
            / (voucher.unlockEndTimestamp - voucher.unlockStartTimestamp);

        if (shareToPay > 0) {
            vouchers[_uid].fundsLeft = voucher.fundsLeft - shareToPay;
            withdrawERC20List(voucher.tokenList, voucher.amountsList, shareToPay);
            vouchers[_uid].unlockStartTimestamp = timeToCalculate;
        }

        return shareToPay;
    }

    function claimStages(uint256 _uid) internal returns(uint256) {
        Voucher memory voucher = vouchers[_uid];

        uint256 shareToPaySum;

        for (uint stageId = 0; stageId < voucher.stagesDates.length; stageId++) {
            if (voucher.stagesDates[stageId] != 0 && block.timestamp > voucher.stagesDates[stageId]) {
                shareToPaySum = shareToPaySum + voucher.stagesShares[stageId];
                vouchers[_uid].stagesDates[stageId] = 0;
            }
        }

        if (shareToPaySum > 0) {
            vouchers[_uid].fundsLeft = voucher.fundsLeft - shareToPaySum;
            withdrawERC20List(voucher.tokenList, voucher.amountsList, shareToPaySum);
        }

        return shareToPaySum;
    }

    function withdrawERC20List(address[] memory _tokenList, uint256[] memory _amountsList, uint256 _share) internal {
        for (uint index = 0; index < _tokenList.length; index++) {
            uint256 amount = _amountsList[index] * _share / PERCENT_DENOMINATOR;
            IERC20(_tokenList[index]).safeTransfer(msg.sender, amount);
        }
    }

    function payWithdrawalFee(uint256 _share) internal {
        uint256 amountToPay = withdrawalFee * _share / PERCENT_DENOMINATOR;
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

    function viewStageDatesById(uint256 _uid) public view returns (uint256[] memory) {
        return vouchers[_uid].stagesDates;
    }

    function viewStageSharesById(uint256 _uid) public view returns (uint256[] memory) {
        return vouchers[_uid].stagesShares;
    }
}