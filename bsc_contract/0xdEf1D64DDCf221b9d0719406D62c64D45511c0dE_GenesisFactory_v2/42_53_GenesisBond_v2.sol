// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "./GenesisBond.sol";
import "./abstract/GenesisFee.sol";

contract GenesisBond_v2 is GenesisBond, GenesisFee {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    struct RevenueShare {
        address partner;
        uint percentage;
    }

    address public partner;

    event PartnerUpdated(address partner);

    function initialize_v2(
        address _partner,
        uint _baseFee,
        uint _partnerFeePercentage
    ) public reinitializer(3) {
        partner = _partner;
        _setBaseFee(_baseFee);
        _setPartnerFeePercentage(_partnerFeePercentage);
    }

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
    ) external virtual override returns (uint) {
        require(_getInitializedVersion() == 3, "Pending initialization");
        require(_depositor != address(0), "Invalid address");
        require(msg.sender == _depositor || AddressUpgradeable.isContract(msg.sender), "no deposits to other address");

        decayDebt();
        uint nativePrice = trueBondPrice();

        // slippage protection
        require(_maxPrice >= nativePrice, "Slippage more than max price");
        uint value = customTreasury.valueOfToken(address(principalToken), _amount);

        uint payout;
        uint fee;

        // Transfer principal token to BondContract
        principalToken.safeTransferFrom(msg.sender, address(this), _amount);

        if (feeInPayout) {
            // payout and fee is computed
            (payout, fee) = payoutFor(value);
        } else {
            // payout and fee is computed
            (payout, fee) = payoutFor(_amount);
            _amount = _amount - fee;
        }

        // must be > 0.01 payout token ( underflow protection )
        require(payout >= 10 ** payoutToken.decimals() / 100, "Bond too small");
        // size protection because there is no slippage
        require(payout <= maxPayout(), "Bond too large");

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

        // total bonded increased
        totalPrincipalBonded = totalPrincipalBonded + _amount;
        // total payout increased
        totalPayoutGiven = totalPayoutGiven + payout;

        require(totalPayoutGiven <= maxTotalPayout, "Max total payout exceeded");

        principalToken.approve(address(customTreasury), _amount);

        if (feeInPayout) {
            // Deposits principal and receives payout tokens
            customTreasury.deposit(address(principalToken), _amount, payout + fee);
            if (fee != 0) {// if fee, send to feeReceiver
                _distributeFee(payoutToken, fee);
            }
        } else {
            // Deposits principal and receives payout tokens
            customTreasury.deposit(address(principalToken), _amount, payout);
            if (fee != 0) {// if fee, send to feeReceiver
                _distributeFee(principalToken, fee);
            }
        }

        // indexed events are emitted
        emit BondCreated(_amount, payout, block.timestamp + terms.vestingTerm, bondId);
        emit BondPriceChanged(bondPrice(), debtRatio());

        return payout;
    }

    /**
      *  @notice split and distribute deposit fees between project and genesis
      *  @param _token IERC20Upgradeable
      *  @param _amount uint
      */
    function _distributeFee(IERC20Upgradeable _token, uint _amount) internal {
        uint partnerAmount = _amount * partnerFeePercentage / 1e6;

        if (partnerAmount > 0 && partner != address(0)) {
            _token.safeTransfer(partner, partnerAmount);
        }

        _token.safeTransfer(feeReceiver, _amount - partnerAmount);
    }

    function _bondPrice() internal virtual override returns (uint _price) {
        return super.bondPrice();
    }

    /**
     *  @notice current fee taken of each bond
     *  @return currentFee_ uint
     */
    function currentFee() public virtual override view returns (uint) {
        return baseFee;
    }

    function setPartner(address _partner) public virtual onlyOwner {
        partner = _partner;

        emit PartnerUpdated(_partner);
    }

    function _setPartner(address _partner) internal {
        partner = _partner;

        emit PartnerUpdated(_partner);
    }
}