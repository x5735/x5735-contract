//SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Vesting is OwnableUpgradeable {
    bool public memberParamsSet;
    bool public isVestingStarted;
    bool public isLiquidityClaimed;

    address public teamAddress;
    address public advisorsAddress;
    address public treasuryAddress;
    address public developmentAddress;
    address public metaverseAddress;

    IERC20Upgradeable public token;

    uint128 public totalSupply;
    uint32 public monthInSeconds;
    uint32 public metaverseLockedPercentage; // 10000 basis points
    uint64 public delayTime; // In seconds

    // MODIFIERS

    modifier vestingAmountCheck(Member storage member) {
        require(
            member.amountClaimed <= member.totalTokenAmount,
            "Vesting Amount Exceeded"
        );
        require(
            block.timestamp >= member.lastClaimed + delayTime + monthInSeconds,
            "Vesting Period is not Done"
        );
        _;
    }

    modifier addressZeroCheck(address _addr) {
        require(_addr != address(0), "Address Zero");
        _;
    }

    modifier presale1Check() {
        require(
            saleTypeToMember[SaleType.PreSale1].isSaleOn,
            "PreSale1 is not On currently"
        );
        _;
    }

    modifier presale2Check() {
        require(
            saleTypeToMember[SaleType.PreSale2].isSaleOn,
            "PreSale2 is not On currently"
        );
        _;
    }

    modifier publicRoundCheck() {
        require(
            saleTypeToMember[SaleType.PublicRound].isSaleOn,
            "PublicRound is not On currently"
        );
        _;
    }

    // STRUCTS
    struct Member {
        uint32 tokenPercentage; // 10000 basis points
        uint32 monthlyPercentage; // 10000 basis points
        uint64 numberOfMonths;
        uint128 lastClaimed;
        uint128 totalTokenAmount;
        uint128 amountClaimed;
        address memberAddress;
        uint64 startTime;
        bool isSaleOn;
    }

    // ENUM
    enum SaleType {
        PreSale1,
        PreSale2,
        PublicRound
    }

    // MAPPINGS
    mapping(SaleType => Member) public saleTypeToMember;
    mapping(address => Member) public addressToMember;

    // EVENTS
    event Initialized();
    event VestingStarted();

    // Claim Function events
    event TeamTokensClaimed(uint128 amountClaimed);
    event AdvisorsTokensClaimed(uint128 amountClaimed);
    event TreasuryTokensClaimed(uint128 amountClaimed);
    event MetaverseTokensClaimed(uint128 amountClaimed);
    event DevAndMarketTokensClaimed(uint128 amountClaimed);
    event LiquidityTokensTransfered(uint128 amountClaimed);
    event ClaimedPreSale1(address indexed user, uint128 amountClaimed);
    event ClaimedPreSale2(address indexed user, uint128 amountClaimed);
    event ClaimedPublicRound(address indexed user, uint128 amountClaimed);

    // Admin Function events
    event DelayTimeSet(uint128 delayTime);
    event SaleStatusChanged(SaleType saleType);
    event MetaverseLockedPercentageChanged(uint128 newPercentage);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        address _teamAddress,
        address _advisorsAddress,
        address _treasuryAddress,
        address _developmentAddress,
        address _metaverseAddress
    ) external initializer {
        token = IERC20Upgradeable(_token);

        __Ownable_init();

        teamAddress = _teamAddress;
        advisorsAddress = _advisorsAddress;
        treasuryAddress = _treasuryAddress;
        developmentAddress = _developmentAddress;
        metaverseAddress = _metaverseAddress;

        totalSupply = 5e9 * 10 ** 18;
        monthInSeconds = 2592000 seconds;
        metaverseLockedPercentage = 3000;

        emit Initialized();
    }

    function startVesting() external onlyOwner {
        require(!isVestingStarted, "Vesting Already Started");

        bool success = token.transferFrom(
            msg.sender,
            address(this),
            totalSupply
        );

        if (!success) revert();

        _setMemberParams(
            teamAddress,
            advisorsAddress,
            treasuryAddress,
            developmentAddress,
            metaverseAddress
        );

        isVestingStarted = true;

        emit VestingStarted();
    }

    function _setMemberParams(
        address _teamAddress,
        address _advisorsAddress,
        address _treasuryAddress,
        address _developmentAddress,
        address _metaverseAddress
    ) private onlyOwner {
        require(!memberParamsSet, "Members Params already Set");
        uint64 blockTimestamp64 = uint64(block.timestamp);
        uint128 blockTimestamp = uint128(block.timestamp);

        addressToMember[_teamAddress] = Member(
            1400,
            0,
            24,
            blockTimestamp,
            (totalSupply * 1400) / 10000,
            0,
            _teamAddress,
            blockTimestamp64,
            false
        );
        addressToMember[_advisorsAddress] = Member(
            600,
            0,
            24,
            blockTimestamp,
            (totalSupply * 600) / 10000,
            0,
            _advisorsAddress,
            blockTimestamp64,
            false
        );
        addressToMember[_treasuryAddress] = Member(
            600,
            33,
            18,
            blockTimestamp,
            (totalSupply * 600) / 10000,
            0,
            _treasuryAddress,
            blockTimestamp64,
            false
        );
        addressToMember[_developmentAddress] = Member(
            1400,
            25,
            24,
            blockTimestamp,
            (totalSupply * 1400) / 10000,
            0,
            _developmentAddress,
            blockTimestamp64,
            false
        );
        addressToMember[_metaverseAddress] = Member(
            3200,
            0,
            0,
            blockTimestamp,
            (totalSupply * 3200) / 10000,
            0,
            _metaverseAddress,
            blockTimestamp64,
            false
        );
        saleTypeToMember[SaleType.PreSale1] = Member(
            1000,
            750,
            12,
            blockTimestamp,
            (totalSupply * 1000) / 10000,
            0,
            msg.sender,
            blockTimestamp64,
            false
        );
        saleTypeToMember[SaleType.PreSale2] = Member(
            1000,
            750,
            12,
            blockTimestamp,
            (totalSupply * 1000) / 10000,
            0,
            msg.sender,
            blockTimestamp64,
            false
        );
        saleTypeToMember[SaleType.PublicRound] = Member(
            500,
            750,
            12,
            blockTimestamp,
            (totalSupply * 500) / 10000,
            0,
            msg.sender,
            blockTimestamp64,
            false
        );

        memberParamsSet = true;
    }

    // CLAIM FUNCTIONS

    function claimTeamTokens() external {
        Member storage member = addressToMember[teamAddress];

        require(msg.sender == member.memberAddress, "ONLY_TEAM");

        _calcTeamAdvTokens(member);

        member.amountClaimed += member.totalTokenAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(
            member.memberAddress,
            member.totalTokenAmount
        );
        if (!success) revert();

        emit TeamTokensClaimed(member.totalTokenAmount);
    }

    function claimAdvisorsTokens() external {
        Member storage member = addressToMember[advisorsAddress];

        require(msg.sender == member.memberAddress, "ONLY_ADVISORS");

        _calcTeamAdvTokens(member);

        member.amountClaimed += member.totalTokenAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(
            member.memberAddress,
            member.totalTokenAmount
        );
        if (!success) revert();

        emit AdvisorsTokensClaimed(member.totalTokenAmount);
    }

    function _calcTeamAdvTokens(Member storage member) internal view {
        require(
            block.timestamp >
                member.startTime + 24 * monthInSeconds + delayTime,
            "Vesting Period not completed"
        );

        require(
            member.amountClaimed <= member.totalTokenAmount,
            "Vesting Amount Exceeded"
        );
    }

    function claimTreasuryTokens()
        external
        vestingAmountCheck(addressToMember[treasuryAddress])
    {
        Member storage member = addressToMember[treasuryAddress];

        require(msg.sender == member.memberAddress, "ONLY_TREASURY");

        uint128 claimableAmount = _treasuryAndDevOperations(member);

        member.amountClaimed += claimableAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(member.memberAddress, claimableAmount);
        if (!success) revert();

        emit TreasuryTokensClaimed(claimableAmount);
    }

    function claimDevAndMarketTokens()
        external
        vestingAmountCheck(addressToMember[developmentAddress])
    {
        Member storage member = addressToMember[developmentAddress];

        require(msg.sender == member.memberAddress, "ONLY_DEVELOPMENT");

        uint128 claimableAmount = _treasuryAndDevOperations(member);

        member.amountClaimed += claimableAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(member.memberAddress, claimableAmount);
        if (!success) revert();

        emit DevAndMarketTokensClaimed(claimableAmount);
    }

    function _treasuryAndDevOperations(
        Member storage member
    ) internal view returns (uint128 claimableAmount) {
        if (
            block.timestamp <
            member.startTime + member.numberOfMonths * monthInSeconds
        ) {
            uint128 monthlyAmount = (member.totalTokenAmount *
                member.monthlyPercentage) / (10000);

            uint128 timePassed = uint128(block.timestamp) - member.lastClaimed;

            claimableAmount = (timePassed / monthInSeconds) * monthlyAmount;
        } else {
            claimableAmount = member.totalTokenAmount - member.amountClaimed;
        }

        return claimableAmount;
    }

    function claimPreSale1(
        address _hotWallet
    ) external presale1Check onlyOwner addressZeroCheck(_hotWallet) {
        Member storage member = saleTypeToMember[SaleType.PreSale1];

        uint128 claimableAmount = _saleOperations(member);

        member.amountClaimed += claimableAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(_hotWallet, claimableAmount);
        if (!success) revert();

        emit ClaimedPreSale1(_hotWallet, claimableAmount);
    }

    function claimPreSale2(
        address _hotWallet
    ) external presale2Check onlyOwner addressZeroCheck(_hotWallet) {
        Member storage member = saleTypeToMember[SaleType.PreSale2];

        uint128 claimableAmount = _saleOperations(member);

        member.amountClaimed += claimableAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(_hotWallet, claimableAmount);
        if (!success) revert();

        emit ClaimedPreSale2(_hotWallet, claimableAmount);
    }

    function claimPublicRound(
        address _hotWallet
    ) external publicRoundCheck onlyOwner addressZeroCheck(_hotWallet) {
        Member storage member = saleTypeToMember[SaleType.PublicRound];

        uint128 claimableAmount = _saleOperations(member);

        member.amountClaimed += claimableAmount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(_hotWallet, claimableAmount);
        if (!success) revert();

        emit ClaimedPublicRound(_hotWallet, claimableAmount);
    }

    function _saleOperations(
        Member storage member
    ) internal view returns (uint128) {
        require(
            member.amountClaimed <= member.totalTokenAmount,
            "Your Vesting is done"
        );

        uint128 claimableAmount;

        if (
            uint128(block.timestamp) < member.startTime + monthInSeconds &&
            member.amountClaimed == 0
        ) {
            claimableAmount = (member.totalTokenAmount * 10) / 100;
        } else if (
            uint128(block.timestamp) >= member.startTime + monthInSeconds &&
            uint128(block.timestamp) < member.startTime + 12 * monthInSeconds
        ) {
            require(
                uint128(block.timestamp) >=
                    member.lastClaimed + monthInSeconds + delayTime,
                "In Vesting"
            );

            uint128 monthlyAmount = (member.totalTokenAmount * 750) / 10000;

            uint128 timePassed = uint128(block.timestamp) - member.lastClaimed;

            if (member.amountClaimed == 0) {
                claimableAmount =
                    (member.totalTokenAmount * 10) /
                    100 +
                    (timePassed / monthInSeconds) *
                    monthlyAmount;
            } else {
                claimableAmount = (timePassed / monthInSeconds) * monthlyAmount;
            }
        } else {
            require(
                uint128(block.timestamp) >=
                    member.lastClaimed + monthInSeconds + delayTime,
                "In Vesting"
            );
            if (member.amountClaimed == 0) {
                claimableAmount = member.totalTokenAmount;
            } else {
                claimableAmount =
                    member.totalTokenAmount -
                    member.amountClaimed;
            }
        }

        return claimableAmount;
    }

    function claimMetaverseTokens(uint128 _amount) external {
        Member storage member = addressToMember[metaverseAddress];

        require(msg.sender == member.memberAddress, "ONLY_METAVERSE");

        require(
            (member.totalTokenAmount * metaverseLockedPercentage) / 10000 >
                _amount,
            "Claimable Amount exceeded"
        );

        require(
            block.timestamp >= member.lastClaimed + delayTime,
            "Wait Delay Time"
        );

        require(
            member.amountClaimed <= member.totalTokenAmount,
            "Vesting Amount Done"
        );

        member.amountClaimed += _amount;
        member.lastClaimed = uint128(block.timestamp);

        bool success = token.transfer(msg.sender, _amount);
        if (!success) revert();

        emit MetaverseTokensClaimed(_amount);
    }

    // ADMIN FUNCTIONS

    function setDelayTime(
        uint64 _delayTime
    ) external onlyOwner returns (uint128) {
        delayTime = _delayTime;
        emit DelayTimeSet(delayTime);

        return delayTime;
    }

    function setSale(SaleType _saleType) external onlyOwner {
        require(!saleTypeToMember[_saleType].isSaleOn, "Already Sale Started");
        saleTypeToMember[_saleType].startTime = uint64(block.timestamp);
        saleTypeToMember[_saleType].lastClaimed = uint64(block.timestamp);
        saleTypeToMember[_saleType].isSaleOn = true;

        emit SaleStatusChanged(_saleType);
    }

    function setMetaverseLockedPercentage(
        uint32 _percentage // 10000 basis points
    ) external onlyOwner {
        metaverseLockedPercentage = _percentage;

        emit MetaverseLockedPercentageChanged(_percentage);
    }

    function claimLiquidityTokens() external onlyOwner {
        require(!isLiquidityClaimed, "Liquidity Already Claimed");
        uint128 claimableAmount = (totalSupply * 3) / 100;

        bool success = token.transfer(msg.sender, claimableAmount);
        if (!success) revert();

        isLiquidityClaimed = true;

        emit LiquidityTokensTransfered(claimableAmount);
    }
}