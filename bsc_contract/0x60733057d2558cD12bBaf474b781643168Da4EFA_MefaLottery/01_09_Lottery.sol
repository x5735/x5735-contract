// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IPancakeSwapLottery {
    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers) external;
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external;
    function closeLottery(uint256 _lotteryId) external;
    function drawFinalNumberAndMakeLotteryClaimable(uint256 _lotteryId, bytes32 _seed, bool _autoInjection) external;
    function injectFunds(uint256 _lotteryId, uint256 _amount) external;
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInCake,
        uint256 _discountDivisor,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external;
    function viewCurrentLotteryId() external returns (uint256);
}

contract MefaLottery is ReentrancyGuard, IPancakeSwapLottery, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public injectorAddress;
    address public operatorAddress;
    address public treasuryAddress;

    uint256 public currentLotteryId;
    uint256 public currentTicketId;

    uint256 public maxNumberTicketsPerBuyOrClaim = 100;
    uint256 public maxPriceTicketInCake = 500000 ether;
    uint256 public minPriceTicketInCake = 0.00000000001 ether;

    uint256 public pendingInjectionNextLottery;

    address public OnoutAddress = 0xE5d8D38E51b54a06866310259c0330d8f3477202;
    address public Deads = 0x000000000000000000000000000000000000dEaD;

    bool public OnoutFeeEnabled = true;
    uint256 private OnoutFee = 20;

    uint256 public withdrawCooldown = 1 days;
    uint256 public constant MIN_DISCOUNT_DIVISOR = 300;
    uint256 public constant MIN_LENGTH_LOTTERY = 5 minutes; // 4 hours - 5 minutes; // 4 hours
    uint256 public constant MAX_LENGTH_LOTTERY = 31 days + 5 minutes; // 31 days
    uint256 public constant MAX_TREASURY_FEE = 3000; // 30%

    uint32 public numbersCount = 6; // §¬§à§Ý-§Ó§à §è§Ú§æ§â §Ó §Ò§Ú§Ý§Ö§ä§Ö §à§ä 2§ç §Õ§à 6§ä§Ú
    IERC20 public cakeToken;

    enum Status {
        Pending,
        Open,
        Close,
        Claimable
    }

    struct Lottery {
        Status status;
        uint256 startTime;
        uint256 endTime;
        uint256 priceTicketInCake;
        uint256 discountDivisor;
        uint256[6] rewardsBreakdown; // 0: 1 matching number // 5: 6 matching numbers
        uint256 treasuryFee; // 500: 5% // 200: 2% // 50: 0.5%
        uint256[6] cakePerBracket;
        uint256[6] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountCollectedInCake;
        uint32 finalNumber;
    }

    struct Ticket {
        uint32 number;
        address owner;
    }

    mapping(uint256 => Lottery) private _lotteries;
    mapping(uint256 => Ticket) private _tickets;
    mapping(uint32 => uint32) private _bracketCalculator;
    mapping(uint256 => mapping(uint32 => uint256)) private _numberTicketsPerLotteryId;
    mapping(address => mapping(uint256 => uint256[])) private _userTicketIdsPerLotteryId;

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier onlyOwnerOrInjector() {
        require((msg.sender == owner()) || (msg.sender == injectorAddress), "Not owner or injector");
        _;
    }

    modifier onlyOwnerOrOperator() {
        require((msg.sender == owner()) || (msg.sender == operatorAddress), "Not owner or operator");
        _;
    }

    event AdminTokenRecovery(address token, uint256 amount);
    event LotteryClose(uint256 indexed lotteryId, uint256 firstTicketIdNextLottery);
    event LotteryInjection(uint256 indexed lotteryId, uint256 injectedAmount);
    event LotteryOpen(
        uint256 indexed lotteryId,
        uint256 startTime,
        uint256 endTime,
        uint256 priceTicketInCake,
        uint256 firstTicketId,
        uint256 injectedAmount
    );
    event LotteryNumberDrawn(uint256 indexed lotteryId, uint256 finalNumber, uint256 countWinningTickets);
    event NewOperatorAndTreasuryAndInjectorAddresses(address operator, address treasury, address injector);
    event TicketsPurchase(address indexed buyer, uint256 indexed lotteryId, uint256 numberTickets);
    event TicketsClaim(address indexed claimer, uint256 amount, uint256 indexed lotteryId, uint256 numberTickets);

    function setOnoutAddress(address _newFeeAddress) public {
        require(msg.sender == OnoutAddress, "Only Onout can change fee address");
        OnoutAddress = _newFeeAddress;
    }

    function setOnoutFeeEnabled(bool _value) public {
        require(msg.sender == OnoutAddress, "Only Onout can enable/disable service fee");
        OnoutFeeEnabled = _value;
    }

    constructor(address _cakeTokenAddress) {
        cakeToken = IERC20(_cakeTokenAddress);

        operatorAddress = owner();
        treasuryAddress = owner();
        injectorAddress = owner();

        // Initializes a mapping
        _bracketCalculator[0] = 1;
        _bracketCalculator[1] = 11;
        _bracketCalculator[2] = 111;
        _bracketCalculator[3] = 1111;
        _bracketCalculator[4] = 11111;
        _bracketCalculator[5] = 111111;

        currentLotteryId++;
        _lotteries[currentLotteryId] = Lottery({
            status: Status.Claimable,
            startTime: block.timestamp,
            endTime:  block.timestamp,
            priceTicketInCake: 0,
            discountDivisor: 0,
            rewardsBreakdown: [uint256(250),uint256(375),uint256(625),uint256(1250),uint256(2500),uint256(5000)],
            treasuryFee: 2000,
            cakePerBracket: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            countWinnersPerBracket: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountCollectedInCake: pendingInjectionNextLottery,
            finalNumber: 1000000
        });
    }

    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers)
        external
        override
        notContract
        nonReentrant
    {
        require(_ticketNumbers.length != 0, "No ticket specified");
        require(_ticketNumbers.length <= maxNumberTicketsPerBuyOrClaim, "Too many tickets");

        require(_lotteries[_lotteryId].status == Status.Open, "Lottery is not open");
        require(block.timestamp < _lotteries[_lotteryId].endTime, "Lottery is over");

        // Calculate number of CAKE to this contract
        uint256 amountCakeToTransfer = _calculateTotalPriceForBulkTickets(
            _lotteries[_lotteryId].discountDivisor,
            _lotteries[_lotteryId].priceTicketInCake,
            _ticketNumbers.length
        );

        if (OnoutFeeEnabled) {
            uint256 amountToOnoutFee = amountCakeToTransfer.mul(OnoutFee).div(100);
            amountCakeToTransfer = amountCakeToTransfer.sub(amountToOnoutFee);
            cakeToken.safeTransferFrom(address(msg.sender), OnoutAddress, amountToOnoutFee);
        }
        // Transfer cake tokens to this contract
        cakeToken.safeTransferFrom(address(msg.sender), address(this), amountCakeToTransfer);

        // Increment the total amount collected for the lottery round
        _lotteries[_lotteryId].amountCollectedInCake += amountCakeToTransfer;

        for (uint256 i = 0; i < _ticketNumbers.length; i++) {
            uint32 thisTicketNumber = _ticketNumbers[i];

            thisTicketNumber = thisTicketNumber - uint32(10)**(6) + 1000000;
            require((thisTicketNumber >= 1000000) && (thisTicketNumber <= 1999999), "Outside range");

            _numberTicketsPerLotteryId[_lotteryId][1 + (thisTicketNumber % 10)]++;
            _numberTicketsPerLotteryId[_lotteryId][11 + (thisTicketNumber % 100)]++;
            _numberTicketsPerLotteryId[_lotteryId][111 + (thisTicketNumber % 1000)]++;
            _numberTicketsPerLotteryId[_lotteryId][1111 + (thisTicketNumber % 10000)]++;
            _numberTicketsPerLotteryId[_lotteryId][11111 + (thisTicketNumber % 100000)]++;
            _numberTicketsPerLotteryId[_lotteryId][111111 + (thisTicketNumber % 1000000)]++;

            _userTicketIdsPerLotteryId[msg.sender][_lotteryId].push(currentTicketId);

            _tickets[currentTicketId] = Ticket({number: thisTicketNumber, owner: msg.sender});

            // Increase lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, _lotteryId, _ticketNumbers.length);
    }

    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external override notContract nonReentrant {
        require(_ticketIds.length == _brackets.length, "Not same length");
        require(_ticketIds.length != 0, "Length must be >0");
        require(_ticketIds.length <= maxNumberTicketsPerBuyOrClaim, "Too many tickets");
        require(_lotteries[_lotteryId].status == Status.Claimable, "Lottery not claimable");

        // Initializes the rewardInCakeToTransfer
        uint256 rewardInCakeToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(_brackets[i] < 6, "Bracket out of range"); // Must be between 0 and 5

            uint256 thisTicketId = _ticketIds[i];

            require(_lotteries[_lotteryId].firstTicketIdNextLottery > thisTicketId, "TicketId too high");
            require(_lotteries[_lotteryId].firstTicketId <= thisTicketId, "TicketId too low");
            require(msg.sender == _tickets[thisTicketId].owner, "Not the owner");

            // Update the lottery ticket owner to 0x address
            _tickets[thisTicketId].owner = address(0);

            uint256 rewardForTicketId = _calculateRewardsForTicketId(_lotteryId, thisTicketId, _brackets[i]);

            // Check user is claiming the correct bracket
            require(rewardForTicketId != 0, "No prize for this bracket");

            if (_brackets[i] != 5) {
                require(
                    _calculateRewardsForTicketId(_lotteryId, thisTicketId, _brackets[i] + 1) == 0,
                    "Bracket must be higher"
                );
            }
            // Increment the reward to transfer
            rewardInCakeToTransfer += rewardForTicketId;
        }

        // Transfer money to msg.sender
        cakeToken.safeTransfer(msg.sender, rewardInCakeToTransfer);

        emit TicketsClaim(msg.sender, rewardInCakeToTransfer, _lotteryId, _ticketIds.length);
    }

    function closeLottery(uint256 _lotteryId) external override onlyOwnerOrOperator nonReentrant {
        require(_lotteries[_lotteryId].status == Status.Open, "Lottery not open");
        require(block.timestamp > _lotteries[_lotteryId].endTime, "Lottery not over");
        _lotteries[_lotteryId].firstTicketIdNextLottery = currentTicketId;

        _lotteries[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId, currentTicketId);
    }

    function drawFinalNumberAndMakeLotteryClaimable(uint256 _lotteryId, bytes32 _seed, bool _autoInjection)
        external
        override
        onlyOwnerOrOperator
        nonReentrant
    {
        require(_lotteries[_lotteryId].status == Status.Close, "Lottery not close");

        // Initialize a number to count addresses in the previous bracket
        uint256 numberAddressesInPreviousBracket;

        // Calculate the amount to share post-treasury fee
        uint256 amountToShareToWinners = (
            ((_lotteries[_lotteryId].amountCollectedInCake) * (10000 - _lotteries[_lotteryId].treasuryFee))
        ) / 10000;

        uint256 randomness = uint(keccak256(abi.encodePacked(
            block.timestamp,
            _seed,
            _lotteryId,
            _lotteries[_lotteryId].firstTicketId,
            _lotteries[_lotteryId].firstTicketIdNextLottery,
            _lotteries[_lotteryId].amountCollectedInCake,
            amountToShareToWinners,
            blockhash(block.number),
            block.coinbase,
            block.prevrandao,
            block.gaslimit,
            tx.gasprice
        )));        
        uint32 finalNumber = uint32(1000000 + (randomness % 1000000));
        // Initializes the amount to withdraw to treasury
        uint256 amountToWithdrawToTreasury;

        // Calculate prizes in CAKE for each bracket by starting from the highest one
        for (uint32 i = 0; i < numbersCount; i++) {
            uint32 j = numbersCount - 1 - i;
            uint32 transformedWinningNumber = _bracketCalculator[j] + (finalNumber % (uint32(10)**(j + 1)));

            _lotteries[_lotteryId].countWinnersPerBracket[j] =
                _numberTicketsPerLotteryId[_lotteryId][transformedWinningNumber] -
                numberAddressesInPreviousBracket;

            // A. If number of users for this _bracket number is superior to 0
            if (
                (_numberTicketsPerLotteryId[_lotteryId][transformedWinningNumber] - numberAddressesInPreviousBracket) !=
                0
            ) {
                // B. If rewards at this bracket are > 0, calculate, else, report the numberAddresses from previous bracket
                if (_lotteries[_lotteryId].rewardsBreakdown[j] != 0) {
                    _lotteries[_lotteryId].cakePerBracket[j] =
                        ((_lotteries[_lotteryId].rewardsBreakdown[j] * amountToShareToWinners) /
                            (_numberTicketsPerLotteryId[_lotteryId][transformedWinningNumber] -
                                numberAddressesInPreviousBracket)) /
                        10000;

                    // Update numberAddressesInPreviousBracket
                    numberAddressesInPreviousBracket = _numberTicketsPerLotteryId[_lotteryId][transformedWinningNumber];
                }
                // A. No CAKE to distribute, they are added to the amount to withdraw to treasury address
            } else {
                _lotteries[_lotteryId].cakePerBracket[j] = 0;

                amountToWithdrawToTreasury +=
                    (_lotteries[_lotteryId].rewardsBreakdown[j] * amountToShareToWinners) /
                    10000;
            }
        }

        // Update internal statuses for lottery
        _lotteries[_lotteryId].finalNumber = finalNumber;
        _lotteries[_lotteryId].status = Status.Claimable;

        if (_autoInjection) {
            pendingInjectionNextLottery = amountToWithdrawToTreasury;
            amountToWithdrawToTreasury = 0;
        }

        amountToWithdrawToTreasury += (_lotteries[_lotteryId].amountCollectedInCake - amountToShareToWinners);

        if (OnoutFeeEnabled && amountToWithdrawToTreasury > 0) {
            // Transfer CAKE to burn address
            uint256 amountToOnoutFee = amountToWithdrawToTreasury.mul(OnoutFee).div(100);
            amountToWithdrawToTreasury = amountToWithdrawToTreasury.sub(amountToOnoutFee);
            cakeToken.safeTransfer(Deads, amountToOnoutFee);
        }

        if(amountToWithdrawToTreasury > 0){
            // Transfer CAKE to treasury address
            cakeToken.safeTransfer(treasuryAddress, amountToWithdrawToTreasury);
        }
        emit LotteryNumberDrawn(currentLotteryId, finalNumber, numberAddressesInPreviousBracket);
    }

    function injectFunds(uint256 _lotteryId, uint256 _amount) external override onlyOwnerOrInjector {
        require(_lotteries[_lotteryId].status == Status.Open, "Lottery not open");

        cakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        _lotteries[_lotteryId].amountCollectedInCake += _amount;

        emit LotteryInjection(_lotteryId, _amount);
    }

    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInCake,
        uint256 _discountDivisor,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external override onlyOwnerOrOperator {
        require(
            (currentLotteryId == 0) || (_lotteries[currentLotteryId].status == Status.Claimable),
            "Not time to start lottery"
        );

        require(
            ((_endTime - block.timestamp) > MIN_LENGTH_LOTTERY) && ((_endTime - block.timestamp) < MAX_LENGTH_LOTTERY),
            "Lottery length outside of range"
        );

        require(_discountDivisor >= MIN_DISCOUNT_DIVISOR, "Discount divisor too low");
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");

        require(
            (_rewardsBreakdown[0] +
                _rewardsBreakdown[1] +
                _rewardsBreakdown[2] +
                _rewardsBreakdown[3] +
                _rewardsBreakdown[4] +
                _rewardsBreakdown[5]) == 10000,
            "Rewards must equal 10000"
        );

        currentLotteryId++;

        _lotteries[currentLotteryId] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: _endTime,
            priceTicketInCake: _priceTicketInCake,
            discountDivisor: _discountDivisor,
            rewardsBreakdown: _rewardsBreakdown,
            treasuryFee: _treasuryFee,
            cakePerBracket: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            countWinnersPerBracket: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountCollectedInCake: pendingInjectionNextLottery,
            finalNumber: 0
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _endTime,
            _priceTicketInCake,
            currentTicketId,
            pendingInjectionNextLottery
        );

        pendingInjectionNextLottery = 0;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress == address(cakeToken), "You dont can recover lottery token");
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function withdrawBank(uint256 _tokenAmount) external onlyOwner {
        require((currentLotteryId == 0) || (_lotteries[currentLotteryId].status == Status.Claimable),
            "You cant withdraw bank while lottery is not finished"
        );
        require(block.timestamp > _lotteries[currentLotteryId].endTime + withdrawCooldown, "Withdraw cooldown!");
        if (OnoutFeeEnabled) {
            uint256 onoutFeeAmount = _tokenAmount.mul(OnoutFee).div(100);
            _tokenAmount = _tokenAmount.sub(onoutFeeAmount);
            cakeToken.safeTransfer(OnoutAddress, onoutFeeAmount);
        }
        cakeToken.safeTransfer(msg.sender, _tokenAmount);
    }

    function setNumbersCount(uint32 _numbersCount) external onlyOwner {
        require(_numbersCount <=6, "numbersCount must be <= 6");
        require(_numbersCount >=2, "numbersCount must be >= 2");
        require((currentLotteryId == 0) || (_lotteries[currentLotteryId].status == Status.Claimable),
            "Has not finished lottery"
        );
        numbersCount = _numbersCount;
    }

    function setMinAndMaxTicketPriceInCake(uint256 _minPriceTicketInCake, uint256 _maxPriceTicketInCake)external onlyOwner {
        require(_minPriceTicketInCake <= _maxPriceTicketInCake, "minPrice must be < maxPrice");
        minPriceTicketInCake = _minPriceTicketInCake;
        maxPriceTicketInCake = _maxPriceTicketInCake;
    }

    function setMaxNumberTicketsPerBuy(uint256 _maxNumberTicketsPerBuy) external onlyOwner {
        require(_maxNumberTicketsPerBuy != 0, "Must be > 0");
        maxNumberTicketsPerBuyOrClaim = _maxNumberTicketsPerBuy;
    }

    function setOperatorAndTreasuryAndInjectorAddresses(address _operatorAddress, address _treasuryAddress, address _injectorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        require(_treasuryAddress != address(0), "Cannot be zero address");
        require(_injectorAddress != address(0), "Cannot be zero address");

        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
        injectorAddress = _injectorAddress;

        emit NewOperatorAndTreasuryAndInjectorAddresses(_operatorAddress, _treasuryAddress, _injectorAddress);
    }

    function setOperatorAddresses(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;
    }

    function calculateTotalPriceForBulkTickets(uint256 _discountDivisor, uint256 _priceTicket,  uint256 _numberTickets) external pure returns (uint256) {
        require(_discountDivisor >= MIN_DISCOUNT_DIVISOR, "Must be >= MIN_DISCOUNT_DIVISOR");
        require(_numberTickets != 0, "Number of tickets must be > 0");
        return _calculateTotalPriceForBulkTickets(_discountDivisor, _priceTicket, _numberTickets);
    }

    function viewCurrentLotteryId() external view override returns (uint256) {
        return currentLotteryId;
    }

    function viewLottery(uint256 _lotteryId) external view returns (Lottery memory) {
        return _lotteries[_lotteryId];
    }

    function viewNumbersAndStatusesForTicketIds(uint256[] calldata _ticketIds)external view returns (uint32[] memory, bool[] memory){
        uint256 length = _ticketIds.length;
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);
        for (uint256 i = 0; i < length; i++) {
            ticketNumbers[i] = _tickets[_ticketIds[i]].number;
            if (_tickets[_ticketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                ticketStatuses[i] = false;
            }
        }
        return (ticketNumbers, ticketStatuses);
    }

    function viewRewardsForTicketId(uint256 _lotteryId, uint256 _ticketId, uint32 _bracket) external view returns (uint256) {
        // Check lottery is in claimable status
        if (_lotteries[_lotteryId].status != Status.Claimable) {
            return 0;
        }
        // Check ticketId is within range
        if (
            (_lotteries[_lotteryId].firstTicketIdNextLottery < _ticketId) &&
            (_lotteries[_lotteryId].firstTicketId >= _ticketId)
        ) {
            return 0;
        }
        return _calculateRewardsForTicketId(_lotteryId, _ticketId, _bracket);
    }

    function viewUserInfoForLotteryId(address _user, uint256 _lotteryId, uint256 _cursor, uint256 _size)
        external view returns (
            uint256[] memory,
            uint32[] memory,
            bool[] memory,
            uint256
        )
    {
        uint256 length = _size;
        uint256 numberTicketsBoughtAtLotteryId = _userTicketIdsPerLotteryId[_user][_lotteryId].length;

        if (length > (numberTicketsBoughtAtLotteryId - _cursor)) {
            length = numberTicketsBoughtAtLotteryId - _cursor;
        }

        uint256[] memory lotteryTicketIds = new uint256[](length);
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            lotteryTicketIds[i] = _userTicketIdsPerLotteryId[_user][_lotteryId][i + _cursor];
            ticketNumbers[i] = _tickets[lotteryTicketIds[i]].number;
            // True = ticket claimed
            if (_tickets[lotteryTicketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                // ticket not claimed (includes the ones that cannot be claimed)
                ticketStatuses[i] = false;
            }
        }
        return (lotteryTicketIds, ticketNumbers, ticketStatuses, _cursor + length);
    }

    function _calculateRewardsForTicketId(uint256 _lotteryId, uint256 _ticketId, uint32 _bracket) internal view returns (uint256) {
        // Retrieve the winning number combination
        uint32 userNumber = _lotteries[_lotteryId].finalNumber;
        // Retrieve the user number combination from the ticketId
        uint32 winningTicketNumber = _tickets[_ticketId].number;
        // Apply transformation to verify the claim provided by the user is true
        uint32 transformedWinningNumber = _bracketCalculator[_bracket] + (winningTicketNumber % (uint32(10)**(_bracket + 1)));
        uint32 transformedUserNumber = _bracketCalculator[_bracket] + (userNumber % (uint32(10)**(_bracket + 1)));
        // Confirm that the two transformed numbers are the same, if not throw
        if (transformedWinningNumber == transformedUserNumber) {
            return _lotteries[_lotteryId].cakePerBracket[_bracket];
        } else {
            return 0;
        }
    }

    function _calculateTotalPriceForBulkTickets(uint256 _discountDivisor, uint256 _priceTicket, uint256 _numberTickets) internal pure returns (uint256) {
        return (_priceTicket * _numberTickets * (_discountDivisor + 1 - _numberTickets)) / _discountDivisor;
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}