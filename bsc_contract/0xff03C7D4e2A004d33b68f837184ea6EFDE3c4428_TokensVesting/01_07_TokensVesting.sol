// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ITokensVesting.sol";

/**
 * @dev Implementation of the {ITokenVesting} interface.
 */
contract TokensVesting is Ownable, ITokensVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 private constant DEFAULT_BASIS = 30 days;

    uint256 public revokedAmount = 0;
    uint256 public revokedAmountWithdrawn = 0;

    enum Participant {
        Unknown,
        PrivateSale,
        PublicSale,
        Team,
        Advisor,
        Liquidity,
        Incentives,
        Marketing,
        Reserve,
        OutOfRange
    }

    enum Status {
        Inactive,
        Active,
        Revoked
    }

    struct VestingInfo {
        uint256 genesisTimestamp;
        uint256 totalAmount;
        uint256 tgeAmount;
        uint256 cliff;
        uint256 duration;
        uint256 releasedAmount;
        uint256 basis;
        address beneficiary;
        Participant participant;
        Status status;
    }

    VestingInfo[] private _beneficiaries;

    event BeneficiaryAdded(address indexed beneficiary, uint256 amount);
    event BeneficiaryActivated(uint256 index, address indexed beneficiary);
    event BeneficiaryRevoked(
        uint256 index,
        address indexed beneficiary,
        uint256 amount
    );

    event Withdraw(address indexed receiver, uint256 amount);

    /**
     * @dev Sets the value for {token}.
     *
     * This value are immutable: it can only be set once during
     * construction.
     */
    constructor(address token_) {
        require(
            token_ != address(0),
            "TokensVesting::constructor: token_ is the zero address!"
        );

        token = IERC20(token_);
    }

    /**
     * @dev Get beneficiary by index_.
     */
    function getBeneficiary(uint256 index_)
        public
        view
        returns (VestingInfo memory)
    {
        return _beneficiaries[index_];
    }

    /**
     * @dev Add beneficiary to vesting plan using default basis.
     * @param beneficiary_ recipient address.
     * @param genesisTimestamp_ genesis timestamp
     * @param totalAmount_ total amount of tokens will be vested.
     * @param tgeAmount_ an amount of tokens will be vested at tge.
     * @param cliff_ cliff duration.
     * @param duration_ linear vesting duration.
     * @param participant_ specific type of {Participant}.
     * Waring: Convert vesting monthly to duration carefully
     * eg: vesting in 9 months => duration = 8 months = 8 * 30 * 24 * 60 * 60
     */
    function addBeneficiary(
        address beneficiary_,
        uint256 genesisTimestamp_,
        uint256 totalAmount_,
        uint256 tgeAmount_,
        uint256 cliff_,
        uint256 duration_,
        uint8 participant_
    ) public {
        addBeneficiaryWithBasis(
            beneficiary_,
            genesisTimestamp_,
            totalAmount_,
            tgeAmount_,
            cliff_,
            duration_,
            participant_,
            DEFAULT_BASIS
        );
    }

    /**
     * @dev Add beneficiary to vesting plan.
     * @param beneficiary_ recipient address.
     * @param genesisTimestamp_ genesis timestamp
     * @param totalAmount_ total amount of tokens will be vested.
     * @param tgeAmount_ an amount of tokens will be vested at tge.
     * @param cliff_ cliff duration.
     * @param duration_ linear vesting duration.
     * @param participant_ specific type of {Participant}.
     * @param basis_ basis duration for linear vesting.
     * Waring: Convert vesting monthly to duration carefully
     * eg: vesting in 9 months => duration = 8 months = 8 * 30 * 24 * 60 * 60
     */
    function addBeneficiaryWithBasis(
        address beneficiary_,
        uint256 genesisTimestamp_,
        uint256 totalAmount_,
        uint256 tgeAmount_,
        uint256 cliff_,
        uint256 duration_,
        uint8 participant_,
        uint256 basis_
    ) public onlyOwner {
        require(
            genesisTimestamp_ >= block.timestamp,
            "TokensVesting::addBeneficiary: genesis too soon!"
        );
        require(
            beneficiary_ != address(0),
            "TokensVesting::addBeneficiary: beneficiary_ is the zero address!"
        );
        require(
            totalAmount_ >= tgeAmount_,
            "TokensVesting::addBeneficiary: totalAmount_ must be greater than or equal to tgeAmount_!"
        );
        require(
            Participant(participant_) > Participant.Unknown &&
                Participant(participant_) < Participant.OutOfRange,
            "TokensVesting::addBeneficiary: participant_ out of range!"
        );
        require(
            genesisTimestamp_ + cliff_ + duration_ <= type(uint256).max,
            "TokensVesting::addBeneficiary: out of uint256 range!"
        );
        require(
            basis_ > 0,
            "TokensVesting::addBeneficiary: basis_ must be greater than 0!"
        );

        VestingInfo storage info = _beneficiaries.push();
        info.beneficiary = beneficiary_;
        info.genesisTimestamp = genesisTimestamp_;
        info.totalAmount = totalAmount_;
        info.tgeAmount = tgeAmount_;
        info.cliff = cliff_;
        info.duration = duration_;
        info.participant = Participant(participant_);
        info.status = Status.Inactive;
        info.basis = basis_;

        emit BeneficiaryAdded(beneficiary_, totalAmount_);
    }

    /**
     * @dev See {ITokensVesting-total}.
     */
    function total() public view returns (uint256) {
        return _getTotalAmount();
    }

    /**
     * @dev See {ITokensVesting-privateSale}.
     */
    function privateSale() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.PrivateSale);
    }

    /**
     * @dev See {ITokensVesting-publicSale}.
     */
    function publicSale() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.PublicSale);
    }

    /**
     * @dev See {ITokensVesting-team}.
     */
    function team() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Team);
    }

    /**
     * @dev See {ITokensVesting-advisor}.
     */
    function advisor() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Advisor);
    }

    /**
     * @dev See {ITokensVesting-liquidity}.
     */
    function liquidity() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Liquidity);
    }

    /**
     * @dev See {ITokensVesting-incentives}.
     */
    function incentives() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Incentives);
    }

    /**
     * @dev See {ITokensVesting-marketing}.
     */
    function marketing() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Marketing);
    }

    /**
     * @dev See {ITokensVesting-reserve}.
     */
    function reserve() public view returns (uint256) {
        return _getTotalAmountByParticipant(Participant.Reserve);
    }

    /**
     * @dev Activate specific beneficiary by index_.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activate(uint256 index_) public onlyOwner {
        require(
            index_ >= 0 && index_ < _beneficiaries.length,
            "TokensVesting::activate: index_ out of range!"
        );

        _activate(index_);
    }

    /**
     * @dev Activate all of beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateAll() public onlyOwner {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _activate(i);
        }
    }

    /**
     * @dev Activate all of private sale beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activatePrivateSale() public onlyOwner {
        return _activateParticipant(Participant.PrivateSale);
    }

    /**
     * @dev Activate all of public sale beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activatePublicSale() public onlyOwner {
        return _activateParticipant(Participant.PublicSale);
    }

    /**
     * @dev Activate all of team beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateTeam() public onlyOwner {
        return _activateParticipant(Participant.Team);
    }

    /**
     * @dev Activate all of advisor beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateAdvisor() public onlyOwner {
        return _activateParticipant(Participant.Advisor);
    }

    /**
     * @dev Activate all of liquidity beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateLiquidity() public onlyOwner {
        return _activateParticipant(Participant.Liquidity);
    }

    /**
     * @dev Activate all of incentives beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateIncentives() public onlyOwner {
        return _activateParticipant(Participant.Incentives);
    }

    /**
     * @dev Activate all of marketing beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateMarketing() public onlyOwner {
        return _activateParticipant(Participant.Marketing);
    }

    /**
     * @dev Activate all of reserve beneficiaries.
     *
     * Only active beneficiaries can claim tokens.
     */
    function activateReserve() public onlyOwner {
        return _activateParticipant(Participant.Reserve);
    }

    /**
     * @dev Revoke specific beneficiary by index_.
     *
     * Revoked beneficiaries cannot vest tokens anymore.
     */
    function revoke(uint256 index_) public onlyOwner {
        require(
            index_ >= 0 && index_ < _beneficiaries.length,
            "TokensVesting::revoke: index_ out of range!"
        );

        _revoke(index_);
    }

    /**
     * @dev See {ITokensVesting-releasable}.
     */
    function releasable() public view returns (uint256) {
        uint256 _releasable = 0;

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            VestingInfo storage info = _beneficiaries[i];
            _releasable =
                _releasable +
                _releasableAmount(
                    info.genesisTimestamp,
                    info.totalAmount,
                    info.tgeAmount,
                    info.cliff,
                    info.duration,
                    info.releasedAmount,
                    info.status,
                    info.basis
                );
        }

        return _releasable;
    }

    /**
     * @dev Returns the total releasable amount of tokens for the specific beneficiary by index.
     */
    function releasable(uint256 index_) public view returns (uint256) {
        require(
            index_ >= 0 && index_ < _beneficiaries.length,
            "TokensVesting::release: index_ out of range!"
        );

        VestingInfo storage info = _beneficiaries[index_];
        uint256 _releasable = _releasableAmount(
            info.genesisTimestamp,
            info.totalAmount,
            info.tgeAmount,
            info.cliff,
            info.duration,
            info.releasedAmount,
            info.status,
            info.basis
        );

        return _releasable;
    }

    /**
     * @dev See {ITokensVesting-privateSaleReleasable}.
     */
    function privateSaleReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.PrivateSale);
    }

    /**
     * @dev See {ITokensVesting-publicSaleReleasable}.
     */
    function publicSaleReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.PublicSale);
    }

    /**
     * @dev See {ITokensVesting-teamReleasable}.
     */
    function teamReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Team);
    }

    /**
     * @dev See {ITokensVesting-advisorReleasable}.
     */
    function advisorReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Advisor);
    }

    /**
     * @dev See {ITokensVesting-liquidityReleasable}.
     */
    function liquidityReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Liquidity);
    }

    /**
     * @dev See {ITokensVesting-incentivesReleasable}.
     */
    function incentivesReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Incentives);
    }

    /**
     * @dev See {ITokensVesting-marketingReleasable}.
     */
    function marketingReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Marketing);
    }

    /**
     * @dev See {ITokensVesting-reserveReleasable}.
     */
    function reserveReleasable() public view returns (uint256) {
        return _getReleasableByParticipant(Participant.Reserve);
    }

    /**
     * @dev See {ITokensVesting-released}.
     */
    function released() public view returns (uint256) {
        return _getReleasedAmount();
    }

    /**
     * @dev See {ITokensVesting-privateSaleReleased}.
     */
    function privateSaleReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.PrivateSale);
    }

    /**
     * @dev See {ITokensVesting-publicSaleReleased}.
     */
    function publicSaleReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.PublicSale);
    }

    /**
     * @dev See {ITokensVesting-teamReleased}.
     */
    function teamReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Team);
    }

    /**
     * @dev See {ITokensVesting-advisorReleased}.
     */
    function advisorReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Advisor);
    }

    /**
     * @dev See {ITokensVesting-liquidityReleased}.
     */
    function liquidityReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Liquidity);
    }

    /**
     * @dev See {ITokensVesting-incentivesReleased}.
     */
    function incentivesReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Incentives);
    }

    /**
     * @dev See {ITokensVesting-marketingReleased}.
     */
    function marketingReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Marketing);
    }

    /**
     * @dev See {ITokensVesting-reserveReleased}.
     */
    function reserveReleased() public view returns (uint256) {
        return _getReleasedAmountByParticipant(Participant.Reserve);
    }

    /**
     * @dev See {ITokensVesting-releaseAll}.
     */
    function releaseAll() public onlyOwner {
        uint256 _releasable = releasable();
        require(
            _releasable > 0,
            "TokensVesting::releaseAll: no tokens are due!"
        );

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _release(i);
        }
    }

    /**
     * @dev See {ITokensVesting-releasePrivateSale}.
     */
    function releasePrivateSale() public onlyOwner {
        return _releaseParticipant(Participant.PrivateSale);
    }

    /**
     * @dev See {ITokensVesting-releasePublicSale}.
     */
    function releasePublicSale() public onlyOwner {
        return _releaseParticipant(Participant.PublicSale);
    }

    /**
     * @dev See {ITokensVesting-releaseTeam}.
     */
    function releaseTeam() public onlyOwner {
        return _releaseParticipant(Participant.Team);
    }

    /**
     * @dev See {ITokensVesting-releaseAdvisor}.
     */
    function releaseAdvisor() public onlyOwner {
        return _releaseParticipant(Participant.Advisor);
    }

    /**
     * @dev See {ITokensVesting-releaseLiquidity}.
     */
    function releaseLiquidity() public onlyOwner {
        return _releaseParticipant(Participant.Liquidity);
    }

    /**
     * @dev See {ITokensVesting-releaseIncentives}.
     */
    function releaseIncentives() public onlyOwner {
        return _releaseParticipant(Participant.Incentives);
    }

    /**
     * @dev See {ITokensVesting-releaseMarketing}.
     */
    function releaseMarketing() public onlyOwner {
        return _releaseParticipant(Participant.Marketing);
    }

    /**
     * @dev See {ITokensVesting-releaseReserve}.
     */
    function releaseReserve() public onlyOwner {
        return _releaseParticipant(Participant.Reserve);
    }

    /**
     * @dev Release all releasable amount of tokens for the sepecific beneficiary by index.
     *
     * Emits a {TokensReleased} event.
     */
    function release(uint256 index_) public {
        require(
            index_ >= 0 && index_ < _beneficiaries.length,
            "TokensVesting::release: index_ out of range!"
        );

        VestingInfo storage info = _beneficiaries[index_];
        require(
            _msgSender() == owner() || _msgSender() == info.beneficiary,
            "TokensVesting::release: unauthorised sender!"
        );

        uint256 unreleased = _releasableAmount(
            info.genesisTimestamp,
            info.totalAmount,
            info.tgeAmount,
            info.cliff,
            info.duration,
            info.releasedAmount,
            info.status,
            info.basis
        );

        require(unreleased > 0, "TokensVesting::release: no tokens are due!");

        info.releasedAmount = info.releasedAmount + unreleased;
        token.safeTransfer(info.beneficiary, unreleased);
        emit TokensReleased(info.beneficiary, unreleased);
    }

    /**
     * @dev Withdraw revoked tokens out of contract.
     *
     * Withdraw amount of tokens upto revoked amount.
     */
    function withdraw(uint256 amount_) public onlyOwner {
        require(amount_ > 0, "TokensVesting::withdraw: Bad params!");
        require(
            amount_ <= revokedAmount - revokedAmountWithdrawn,
            "TokensVesting::withdraw: Amount exceeded revoked amount withdrawable!"
        );

        revokedAmountWithdrawn = revokedAmountWithdrawn + amount_;
        token.safeTransfer(_msgSender(), amount_);
        emit Withdraw(_msgSender(), amount_);
    }

    /**
     * @dev Release all releasable amount of tokens for the sepecific beneficiary by index.
     *
     * Emits a {TokensReleased} event.
     */
    function _release(uint256 index_) private {
        VestingInfo storage info = _beneficiaries[index_];
        uint256 unreleased = _releasableAmount(
            info.genesisTimestamp,
            info.totalAmount,
            info.tgeAmount,
            info.cliff,
            info.duration,
            info.releasedAmount,
            info.status,
            info.basis
        );

        if (unreleased > 0) {
            info.releasedAmount = info.releasedAmount + unreleased;
            token.safeTransfer(info.beneficiary, unreleased);
            emit TokensReleased(info.beneficiary, unreleased);
        }
    }

    function _getTotalAmount() private view returns (uint256) {
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            totalAmount = totalAmount + _beneficiaries[i].totalAmount;
        }
        return totalAmount;
    }

    function _getTotalAmountByParticipant(Participant participant_)
        private
        view
        returns (uint256)
    {
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i].participant == participant_) {
                totalAmount = totalAmount + _beneficiaries[i].totalAmount;
            }
        }
        return totalAmount;
    }

    function _getReleasedAmount() private view returns (uint256) {
        uint256 releasedAmount = 0;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            releasedAmount = releasedAmount + _beneficiaries[i].releasedAmount;
        }
        return releasedAmount;
    }

    function _getReleasedAmountByParticipant(Participant participant_)
        private
        view
        returns (uint256)
    {
        require(
            Participant(participant_) > Participant.Unknown &&
                Participant(participant_) < Participant.OutOfRange,
            "TokensVesting::_getReleasedAmountByParticipant: participant_ out of range!"
        );

        uint256 releasedAmount = 0;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i].participant == participant_)
                releasedAmount =
                    releasedAmount +
                    _beneficiaries[i].releasedAmount;
        }
        return releasedAmount;
    }

    function _releasableAmount(
        uint256 genesisTimestamp_,
        uint256 totalAmount_,
        uint256 tgeAmount_,
        uint256 cliff_,
        uint256 duration_,
        uint256 releasedAmount_,
        Status status_,
        uint256 basis_
    ) private view returns (uint256) {
        if (status_ == Status.Inactive) {
            return 0;
        }

        if (status_ == Status.Revoked) {
            return totalAmount_ - releasedAmount_;
        }

        return
            _vestedAmount(genesisTimestamp_, totalAmount_, tgeAmount_, cliff_, duration_, basis_) -
            releasedAmount_;
    }

    function _vestedAmount(
        uint256 genesisTimestamp_,
        uint256 totalAmount_,
        uint256 tgeAmount_,
        uint256 cliff_,
        uint256 duration_,
        uint256 basis_
    ) private view returns (uint256) {
        require(
            totalAmount_ >= tgeAmount_,
            "TokensVesting::_vestedAmount: Bad params!"
        );

        if (block.timestamp < genesisTimestamp_) {
            return 0;
        }

        uint256 timeLeftAfterStart = block.timestamp - genesisTimestamp_;

        if (timeLeftAfterStart < cliff_) {
            return tgeAmount_;
        }

        uint256 linearVestingAmount = totalAmount_ - tgeAmount_;
        if (timeLeftAfterStart >= cliff_ + duration_) {
            return linearVestingAmount + tgeAmount_;
        }

        uint256 releaseMilestones = (timeLeftAfterStart - cliff_) / basis_ + 1;
        uint256 totalReleaseMilestones = (duration_ + basis_ - 1) / basis_ + 1;
        return
            (linearVestingAmount / totalReleaseMilestones) *
            releaseMilestones +
            tgeAmount_;
    }

    function _activate(uint256 index_) private {
        VestingInfo storage info = _beneficiaries[index_];
        if (info.status == Status.Inactive) {
            info.status = Status.Active;
            emit BeneficiaryActivated(index_, info.beneficiary);
        }
    }

    function _activateParticipant(Participant participant_) private {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            VestingInfo storage info = _beneficiaries[i];
            if (info.participant == participant_) {
                _activate(i);
            }
        }
    }

    function _revoke(uint256 index_) private {
        VestingInfo storage info = _beneficiaries[index_];
        if (info.status == Status.Revoked) {
            return;
        }

        uint256 _releasable = _releasableAmount(
            info.genesisTimestamp,
            info.totalAmount,
            info.tgeAmount,
            info.cliff,
            info.duration,
            info.releasedAmount,
            info.status,
            info.basis
        );

        uint256 oldTotalAmount = info.totalAmount;
        info.totalAmount = info.releasedAmount + _releasable;

        uint256 revokingAmount = oldTotalAmount - info.totalAmount;
        if (revokingAmount > 0) {
            info.status = Status.Revoked;
            revokedAmount = revokedAmount + revokingAmount;
            emit BeneficiaryRevoked(index_, info.beneficiary, revokingAmount);
        }
    }

    function _getReleasableByParticipant(Participant participant_)
        private
        view
        returns (uint256)
    {
        uint256 _releasable = 0;

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            VestingInfo storage info = _beneficiaries[i];
            if (info.participant == participant_) {
                _releasable =
                    _releasable +
                    _releasableAmount(
                        info.genesisTimestamp,
                        info.totalAmount,
                        info.tgeAmount,
                        info.cliff,
                        info.duration,
                        info.releasedAmount,
                        info.status,
                        info.basis
                    );
            }
        }

        return _releasable;
    }

    function _releaseParticipant(Participant participant_) private {
        uint256 _releasable = _getReleasableByParticipant(participant_);
        require(
            _releasable > 0,
            "TokensVesting::_releaseParticipant: no tokens are due!"
        );

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i].participant == participant_) {
                _release(i);
            }
        }
    }
}