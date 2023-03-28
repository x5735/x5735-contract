// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IGenesisTreasury.sol";
import "./interfaces/IGenesisBondNFT.sol";
import "./PolicyUpgradeable.sol";

contract GenesisBond is Initializable, PolicyUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /* ======== EVENTS ======== */

    event FeeReceiverChanged(address indexed newFeeReceiver);
    event MaxTotalPayoutChanged(uint newMaxTotalPayout);
    event RedeemerToggled(address indexed owner, address indexed redeemer, bool approved);
    event BondCreated(uint deposit, uint payout, uint expires, uint indexed bondId);
    event BondRedeemed(uint indexed bondId, address indexed recipient, uint payout, uint remaining);
    event BondPriceChanged(uint internalPrice, uint debtRatio);
    event BondInitialized(uint controlVariable, uint vestingTerm, uint minimumPrice, uint maxPayout, uint maxDebt, uint maxTotalPayout, uint initialDebt, uint lastDecay);
    event TermsSet(PARAMETER parameter, uint input);

    /* ======== STATE VARIABLES ======== */

    IERC20MetadataUpgradeable public payoutToken; // token paid for principal
    IERC20Upgradeable public principalToken; // inflow token
    IGenesisTreasury public customTreasury; // pays for and receives principal
    IGenesisBondNFT public bondNft;
    EnumerableSetUpgradeable.UintSet internal bondIssuedIds;
    address public feeReceiver;

    uint public totalPrincipalBonded;
    uint public totalPayoutGiven;
    uint public maxTotalPayout;

    Terms public terms; // stores terms for new bonds
    FeeTiers[] public feeTiers; // stores fee tiers

    mapping(uint => Bond) public bondInfo; // stores bond information for nfts
    mapping(address => mapping(address => bool)) public redeemerApproved; // Stores user approved redeemers

    uint public totalDebt; // total value of outstanding bonds; used for pricing
    uint public lastDecay; // reference block for debt decay

    bool public feeInPayout;
    /* ======== STRUCTS ======== */

    struct FeeTiers {
        uint tierCeilings; // principal bonded till next tier
        uint fees; // in ten-thousandths (i.e. 33300 = 3.33%)
    }

    // Info for creating new bonds
    struct Terms {
        uint controlVariable; // scaling variable for price. times 1e18
        uint vestingTerm; // in seconds
        uint minimumPrice; // vs principal value
        uint maxPayout; // in thousandths of a % of total supply. i.e. 500 = 0.5%
        uint maxDebt; // payout token decimal debt ratio, max % total supply created as debt
    }

    // Info for bond holder
    struct Bond {
        uint payout; // payout token remaining to be paid
        uint vesting; // seconds left to vest
        uint lastBlockTimestamp; // Last interaction
        uint truePricePaid; // Price paid (principal tokens per payout token) in ten-millionths - 4000000 = 0.4
    }

    /*
     * @param _config [_customTreasury, _principalToken, _feeReceiver, _bondNft, _initialOwner]
     * @param _tierCeilings
     * @param _fees
     * @param _feeInPayout
     * @param _proxyOwner
     */
    function initialize(
        address[5] calldata _config,
        uint[] memory _tierCeilings,
        uint[] memory _fees,
        bool _feeInPayout,
        address _proxyOwner
    ) public initializer {
        __Ownable_init();
        transferOwnership(_proxyOwner);

        require(_config[0] != address(0), "customTreasury cannot be zero");
        customTreasury = IGenesisTreasury(_config[0]);
        payoutToken = IERC20MetadataUpgradeable(IGenesisTreasury(_config[0]).payoutToken());

        require(_config[1] != address(0), "principalToken cannot be zero");
        principalToken = IERC20Upgradeable(_config[1]);

        require(_config[2] != address(0), "feeReceiver cannot be zero");
        feeReceiver = _config[2];

        uint tiersLength = _tierCeilings.length;
        require(tiersLength == _fees.length, "tier length != fee length");
        require(_config[3] != address(0), "bondNft cannot be zero");
        bondNft = IGenesisBondNFT(_config[3]);

        require(_config[4] != address(0), "policy cannot be zero");
        initPolicy(_config[4]);
        for (uint i; i < tiersLength; i++) {
            require(_fees[i] <= 1e6, "Invalid fee");
            feeTiers.push(
                FeeTiers({tierCeilings: _tierCeilings[i], fees: _fees[i]})
            );
        }
        feeInPayout = _feeInPayout;
    }

    /* ======== INITIALIZATION ======== */

    /**
     *  @notice initializes bond parameters
     *  @param _controlVariable uint
     *  @param _vestingTerm uint
     *  @param _minimumPrice uint
     *  @param _maxPayout uint
     *  @param _maxDebt uint
     *  @param _initialDebt uint
     */
    function initializeBond(
        uint _controlVariable,
        uint _vestingTerm,
        uint _minimumPrice,
        uint _maxPayout,
        uint _maxDebt,
        uint _maxTotalPayout,
        uint _initialDebt
    ) external reinitializer(2) {
        require(currentDebt() == 0, "Debt must be 0" );
        require(_vestingTerm >= 129600, "Vesting must be >= 36 hours");
        require(_maxPayout <= 1000, "Payout cannot be above 1 percent");
        require(_controlVariable > 0, "CV must be above 0");

        terms = Terms ({
            controlVariable: _controlVariable,
            vestingTerm: _vestingTerm,
            minimumPrice: _minimumPrice,
            maxPayout: _maxPayout,
            maxDebt: _maxDebt
        });
        maxTotalPayout = _maxTotalPayout;
        totalDebt = _initialDebt;
        lastDecay = block.timestamp;
        emit BondInitialized(_controlVariable, _vestingTerm, _minimumPrice, _maxPayout, _maxDebt, _maxTotalPayout, _initialDebt, block.timestamp);
    }

    /* ======== POLICY FUNCTIONS ======== */

    enum PARAMETER { VESTING, PAYOUT, DEBT, MIN_PRICE }
    /**
     *  @notice set parameters for new bonds
     *  @param _parameter PARAMETER
     *  @param _input uint
     */
    function setBondTerms(PARAMETER _parameter, uint _input)
        external
        onlyPolicy
    {
        if (_parameter == PARAMETER.VESTING) {
            // 0
            require(_input >= 129600, "Vesting must be >= 36 hours");
            terms.vestingTerm = _input;
        } else if (_parameter == PARAMETER.PAYOUT) {
            // 1
            require(_input <= 1000, "Payout cannot be above 1 percent");
            terms.maxPayout = _input;
        } else if (_parameter == PARAMETER.DEBT) {
            // 2
            terms.maxDebt = _input;
        } else if (_parameter == PARAMETER.MIN_PRICE) {
            // 3
            terms.minimumPrice = _input;
        }
        emit TermsSet(_parameter, _input);
    }

    /**
    * @notice substitute the current bond terms struct with a new one
    * @ param _terms Term struct
    */
    function batchSetBondTerms(Terms memory _terms) external onlyPolicy {
        require(_terms.vestingTerm >= 129600, "Vesting must be >= 36 hours");
        require(_terms.maxPayout <= 1000, "Payout cannot be above 1 percent");

        terms = _terms;
    }

    function setMaxTotalPayout(uint _maxTotalPayout) external onlyPolicy {
        require(_maxTotalPayout >= totalPayoutGiven, "maxTotalPayout <= totalPayout");
        maxTotalPayout = _maxTotalPayout;
        emit MaxTotalPayoutChanged(_maxTotalPayout);
    }

    /* ======== USER FUNCTIONS ======== */

    /**
     *  @notice deposit bond
     *  @param _amount uint
     *  @param _maxPrice uint
     *  @param _depositor address
     *  @return uint
     */
    function deposit(
        uint _amount,
        uint _maxPrice,
        address _depositor
    ) external virtual returns (uint) {
        require(_depositor != address(0), "Invalid address");
        require(msg.sender == _depositor || AddressUpgradeable.isContract(msg.sender), "no deposits to other address");

        decayDebt();
        uint nativePrice = trueBondPrice();
        require( _maxPrice >= nativePrice, "Slippage more than max price" ); // slippage protection
        uint value = customTreasury.valueOfToken( address(principalToken), _amount);

        uint payout;
        uint fee;

        // Transfer principal token to BondContract
        principalToken.safeTransferFrom(msg.sender, address(this), _amount);

        if(feeInPayout) {
            (payout, fee) = payoutFor(value); // payout and fee is computed
        } else {
            (payout, fee) = payoutFor(_amount); // payout and fee is computed
            _amount = _amount - fee;
        }

        require(payout >= 10 ** payoutToken.decimals() / 100, "Bond too small" ); // must be > 0.01 payout token ( underflow protection )
        require(payout <= maxPayout(), "Bond too large"); // size protection because there is no slippage

        uint bondId = bondNft.mint(_depositor, address(this));
        // depositor info is stored
        bondInfo[bondId] = Bond({
            payout: payout,
            vesting: terms.vestingTerm,
            lastBlockTimestamp: block.timestamp,
            truePricePaid: trueBondPrice()
        });
        bondIssuedIds.add(bondId);

        // total debt is increased
        totalDebt = totalDebt + value;

        require(totalDebt <= terms.maxDebt, "Max capacity reached");

        totalPrincipalBonded = totalPrincipalBonded + _amount; // total bonded increased
        totalPayoutGiven = totalPayoutGiven + payout; // total payout increased
        require(totalPayoutGiven <= maxTotalPayout, "Max total payout exceeded");

        principalToken.approve(address(customTreasury), _amount);

        if(feeInPayout) {
            // Deposits principal and receives payout tokens
            customTreasury.deposit(address(principalToken), _amount, payout + fee);
            if(fee != 0) { // if fee, send to feeReceiver
                payoutToken.safeTransfer(feeReceiver, fee);
            }
        } else {
            // Deposits principal and receives payout tokens
            customTreasury.deposit(address(principalToken), _amount, payout);
            if(fee != 0) { // if fee, send to feeReceiver
                principalToken.safeTransfer(feeReceiver, fee);
            }
        }

        // indexed events are emitted
        emit BondCreated(_amount, payout, block.timestamp + terms.vestingTerm, bondId);

        emit BondPriceChanged(_bondPrice(), debtRatio());
        return payout;
    }

    /**
     *  @notice redeem bond for user
     *  @param _bondId uint
     *  @return uint
     */
    function redeem(uint _bondId) public returns (uint) {
        Bond memory info = bondInfo[_bondId];
        require(info.lastBlockTimestamp > 0, "not a valid bond id");
        require(info.payout > 0, "nothing to redeem");

        address owner = bondNft.ownerOf(_bondId);
        require(msg.sender == owner || msg.sender == address(bondNft) || redeemerApproved[owner][msg.sender], "not approved");

        uint percentVested = percentVestedFor(_bondId); // (seconds since last interaction / vesting term remaining)

        if (percentVested >= 10000) { // if fully vested
            delete bondInfo[_bondId]; // delete user info
            emit BondRedeemed(_bondId, owner, info.payout, 0); // emit bond data
            payoutToken.safeTransfer(owner, info.payout);
            return info.payout;

        } else { // if unfinished
            // calculate payout vested
            uint payout = info.payout * percentVested / 10_000;

            // store updated deposit info
            bondInfo[_bondId] = Bond({
                payout: info.payout - payout,
                vesting: info.vesting - (block.timestamp - info.lastBlockTimestamp),
                lastBlockTimestamp: block.timestamp,
                truePricePaid: info.truePricePaid
            });

            emit BondRedeemed(_bondId, owner, payout, bondInfo[_bondId].payout);
            payoutToken.safeTransfer(owner, payout);
            return payout;
        }
    }

    /**
     *  @notice redeem bonds for user
     *  @param _bondIds uint[]
     */
    function batchRedeem(uint[] calldata _bondIds) external returns (uint payout) {
        uint length = _bondIds.length;
        for (uint i = 0; i < length; i++) {
            payout += redeem(_bondIds[i]);
        }
    }

    /**
     *  @notice allows or disallows a third party address to redeem bonds on behalf of user
     *  @param redeemer address
    */
    function toggleRedeemer(address redeemer) external {
        redeemerApproved[msg.sender][redeemer] = !redeemerApproved[msg.sender][redeemer];
        emit RedeemerToggled(msg.sender, redeemer, redeemerApproved[msg.sender][redeemer]);
    }

    /* ======== INTERNAL HELPER FUNCTIONS ======== */

    /**
     *  @notice reduce total debt
     */
    function decayDebt() internal {
        totalDebt = totalDebt - debtDecay();
        lastDecay = block.timestamp;
    }

    /**
     *  @notice calculate current bond price and remove floor if above
     *  @return price_ uint
     */
    function _bondPrice() internal virtual returns (uint price_) {
        price_ = terms.controlVariable * debtRatio() / 1e18;
        if (price_ < terms.minimumPrice) {
            price_ = terms.minimumPrice;
        } else if (terms.minimumPrice != 0) {
            terms.minimumPrice = 0;
        }
    }

    /* ======== VIEW FUNCTIONS ======== */

    /**
     *  @notice calculate current bond premium
     *  @return price_ uint
     */
    function bondPrice() public view returns (uint price_) {
        price_ = terms.controlVariable * debtRatio() / 1e18;
        if (price_ < terms.minimumPrice) {
            price_ = terms.minimumPrice;
        }
    }

    /**
     *  @notice calculate true bond price a user pays
     *  @return price_ uint
     */
    function trueBondPrice() public view returns (uint price_) {
        price_ = bondPrice() * 1e6 / (1e6 - currentFee());
    }

    /**
     *  @notice determine maximum bond size
     *  @return uint
     */
    function maxPayout() public view returns (uint) {
        return payoutToken.totalSupply() * terms.maxPayout / 100_000;
    }

    /**
     *  @notice calculate user's interest due for new bond, accounting for Fee.
     If fee is in payout then takes in the already calculated value. If fee is in principal token
     than takes in the amount of principal being deposited and then calculates the fee based on
     the amount of principal and not in terms of the payout token
     *  @param _value uint
     *  @return _payout uint
     *  @return _fee uint
     */
    function payoutFor(uint _value) public view returns (uint _payout, uint _fee) {
        if(feeInPayout) {
            uint total = _value * 1e18 / bondPrice();
            _fee = total * currentFee() / 1e6;
            _payout = total - _fee;
        } else {
            _fee = _value * currentFee() / 1e6;
            _payout = customTreasury.valueOfToken(address(principalToken), (_value - _fee)) * 1e18 / bondPrice();
        }
    }

    /**
     *  @notice calculate current ratio of debt to payout token supply
     *  @notice protocols using this system should be careful when quickly adding large %s to total supply
     *  @return debtRatio_ uint
     */
    function debtRatio() public view returns (uint) {
        return currentDebt() * 10 ** payoutToken.decimals() / payoutToken.totalSupply();
    }

    /**
     *  @notice calculate debt factoring in decay
     *  @return uint
     */
    function currentDebt() public view returns (uint) {
        return totalDebt - debtDecay();
    }

    /**
     *  @notice amount to decay total debt by
     *  @return decay_ uint
     */
    function debtDecay() public view returns (uint decay_) {
        if (terms.vestingTerm == 0)
            return totalDebt;
        uint timestampSinceLast = block.timestamp - lastDecay;
        decay_ = totalDebt * timestampSinceLast / terms.vestingTerm;
        if (decay_ > totalDebt) {
            decay_ = totalDebt;
        }
    }

    /**
     *  @notice calculate how far into vesting a depositor is
     *  @param _bondId uint
     *  @return percentVested_ uint
     */
    function percentVestedFor(uint _bondId) public view returns (uint percentVested_) {
        Bond memory bond = bondInfo[_bondId];
        uint timestampSinceLast = block.timestamp - bond.lastBlockTimestamp;
        uint vesting = bond.vesting;

        if (vesting > 0) {
            percentVested_ = timestampSinceLast * 10_000 / vesting;
        } else {
            percentVested_ = 0;
        }
    }

    /**
     *  @notice calculate amount of payout token available for claim by depositor
     *  @param _bondId uint
     *  @return pendingPayout_ uint
     */
    function pendingPayoutFor(uint _bondId)
        external
        view
        returns (uint pendingPayout_)
    {
        uint percentVested = percentVestedFor(_bondId);
        uint payout = bondInfo[_bondId].payout;

        if (percentVested >= 10000) {
            pendingPayout_ = payout;
        } else {
            pendingPayout_ = payout * percentVested / 10000;
        }
    }

    /**
     * @dev Returns the pending vesting in seconds of the `_bondId` token.
     *  @param _bondId uint
     *  @return vestingSeconds_ uint
     *
     */
    function pendingVesting(uint _bondId) external view returns (uint vestingSeconds_) {
        uint vesting = bondInfo[_bondId].vesting;
        uint percentVested = percentVestedFor(_bondId);

        if (percentVested >= 10000) {
            vestingSeconds_ = 0;
        } else {
            vestingSeconds_ = vesting - ((vesting * percentVested) / 10000);
        }
    }

    /**
     *  @notice calculate all bondNft ids for sender
     *  @return bondNftIds uint[]
     */
    function userBondIds()
        external
        view
        returns (uint[] memory)
    {
        return getBondIds(msg.sender);
    }

    /**
     *  @notice calculate all bondNft ids for user
     *  @return bondNftIds uint[]
     */
    function getBondIds(address user)
        public
        view
        returns (uint[] memory)
    {
        uint balance = bondNft.balanceOf(user);
        return getBondIdsInRange(user, 0, balance);
    }

    /**
     *  @notice calculate bondNft ids in range for user
     *  @return bondNftIds uint[]
     */
    function getBondIdsInRange(address user, uint start, uint end)
        public
        view
        returns (uint[] memory)
    {
        uint[] memory result = new uint[](end - start);
        for (uint i = start; i < end; i++) {
            uint tokenId = bondNft.tokenOfOwnerByIndex(user, i);
            if (bondIssuedIds.contains(tokenId))
                result[i - start] = tokenId;
        }
        return result;
    }

    /**
     *  @notice current fee taken of each bond
     *  @return currentFee_ uint
     */
    function currentFee() public virtual view returns (uint currentFee_) {
        uint tierLength = feeTiers.length;

        for (uint i; i < tierLength; i++) {
            if (totalPrincipalBonded < feeTiers[i].tierCeilings) {
                return feeTiers[i].fees;
            }
        }

        return feeTiers[tierLength - 1].fees;
    }

    function allIssuedBondIds() external view returns (uint[] memory) {
        return bondIssuedIds.values();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}