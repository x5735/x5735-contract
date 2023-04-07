// SPDX-License-Identifier: MIT

//** DCB Crowdfunding Contract */
//** Author: Aceson & Aaron 2023.3 */

pragma solidity 0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IDCBCrowdfunding.sol";
import "./interfaces/IDCBInvestments.sol";
import "./interfaces/IDCBWalletStore.sol";
import "./interfaces/IDCBTiers.sol";
import "./interfaces/IDCBPlatformVesting.sol";

contract DCBCrowdfunding is IDCBCrowdfunding, Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;

    /**
     *
     * @dev InvestorInfo is the struct type which store investor information
     *
     */
    struct InvestorInfo {
        uint256 joinDate;
        uint256 investAmount;
        address wallet;
        bool active;
    }

    struct InvestorAllocation {
        uint256 shares;
        bool active;
    }

    /**
     *
     * @dev AgreementInfo will have information about agreement.
     * It will contains agreement details between innovator and investor.
     * For now, innovatorWallet will reflect owner of the platform.
     *
     */
    struct AgreementInfo {
        uint256 totalTokenOnSale;
        uint256 hardcap;
        uint256 createDate;
        uint256 startDate;
        uint256 endDate;
        uint8 minTier;
        IERC20 token;
        uint256 vote;
        uint256 totalInvestFund;
        mapping(address => InvestorInfo) investorList;
    }

    /* keccak256("I agree to the terms and conditions") */
    bytes32 internal constant AGREEMENT_HASH = 0x5092667f9e8ff6ee71b4390edf6b0f5e27a1a54e802444fa8c980c19a04c550d;

    /**
     *
     * @dev this variable is the instance of wallet storage
     *
     */
    IDCBWalletStore public walletStore;

    /**
     *
     * @dev this variable stores total number of participants
     *
     */
    address[] private _participants;

    /**
     *
     * @dev this variable stores total number of registered users
     *
     */
    address[] private _registeredUsers;

    /**
     *
     * @dev this variable is the instance of investment contract
     *
     */
    IDCBInvestments public investment;

    /**
     *
     * @dev this variable is the instance of vesting contract
     *
     */
    IDCBPlatformVesting public vesting;

    /**
     *
     * @dev dcbAgreement store agreements info of this contract.
     *
     */
    AgreementInfo public dcbAgreement;

    /**
     *
     * @dev this variable is the instance of tiers contract
     *
     */
    IDCBTiers public tiers;

    /**
     *
     * @dev this variable is the instance of token on sale
     *
     */
    IERC20 public saleToken;

    /**
     *
     * @dev userAllocation stores each users allocated amount
     *
     */
    mapping(address => InvestorAllocation) public userAllocation;
    mapping(address => bool) public isComplied;

    uint256 public totalShares;

    event UserRegistered(address user);

    modifier onlyValidSigner(bytes memory _sig) {
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(AGREEMENT_HASH), _sig);
        require(msg.sender == signer, "Invalid signer");
        _;
    }

    function initialize(Params memory p) external initializer {
        walletStore = IDCBWalletStore(p.walletStoreAddr);
        investment = IDCBInvestments(p.investmentAddr);
        vesting = IDCBPlatformVesting(p.vestingAddr);
        saleToken = IERC20(p.saleTokenAddr);
        tiers = IDCBTiers(p.tiersAddr);

        /**
         * generate the new agreement
         */
        dcbAgreement.totalTokenOnSale = p.totalTokenOnSale;
        dcbAgreement.hardcap = p.hardcap;
        dcbAgreement.createDate = block.timestamp;
        dcbAgreement.startDate = p.startDate;
        dcbAgreement.endDate = p.startDate + 24 hours;
        dcbAgreement.token = IERC20(p.paymentToken);
        dcbAgreement.vote = 0;
        dcbAgreement.totalInvestFund = 0;
        dcbAgreement.minTier = p.minTier;

        /**
         * emit the agreement generation event
         */
        emit CreateAgreement(p);
    }

    /**
     *
     * @dev set a users allocation
     *
     * @param {_sig} Signature from the user
     *
     * @return {bool} return status of operation
     *
     */
    function registerForAllocation(bytes memory _sig) external override onlyValidSigner(_sig) returns (bool) {
        (bool _flag, uint256 _tier, uint256 _multi) = tiers.getTierOfUser(msg.sender);

        require(_flag && _tier >= dcbAgreement.minTier, "User not part of required tier");
        require(walletStore.isVerified(msg.sender), "User is not verified");
        require(!userAllocation[msg.sender].active, "Already registered");
        require(block.timestamp <= dcbAgreement.startDate, "Registration closed");

        uint256 shares = (2 ** _tier) * _multi;

        userAllocation[msg.sender].active = true;
        userAllocation[msg.sender].shares = shares;
        isComplied[msg.sender] = true;
        _registeredUsers.push(msg.sender);

        totalShares = totalShares.add(shares);
        emit UserRegistered(msg.sender);

        return true;
    }

    function acceptTerms(bytes memory _sig) external override onlyValidSigner(_sig) returns (bool) {
        require(walletStore.isVerified(msg.sender), "User is not verified");

        isComplied[msg.sender] = true;

        return true;
    }

    /**
     *
     * @dev investor join available agreement. Already complied users can pass empty signature
     *
     * @param {uint256} Deposit amount
     * @param {bytes} Signature of user
     *
     * @return {bool} return if investor successfully joined to the agreement
     *
     */
    function fundAgreement(uint256 _investFund) external override nonReentrant returns (bool) {
        InvestorAllocation memory user = userAllocation[msg.sender];

        /**
         * check if project has provided tokens
         */
        require(
            saleToken.balanceOf(address(vesting)) >= dcbAgreement.totalTokenOnSale, "Tokens not received from project"
        );

        /**
         * check if investor is willing to invest any funds
         */
        require(_investFund > 0, "You cannot invest 0");

        /**
         * check if startDate has started
         */
        require(block.timestamp >= dcbAgreement.startDate, "Crowdfunding not open");

        /**
         * check if endDate has already passed
         */
        require(block.timestamp < dcbAgreement.endDate, "Crowdfunding ended");

        require(dcbAgreement.totalInvestFund.add(_investFund) <= dcbAgreement.hardcap, "Hardcap already met");

        require(isComplied[msg.sender], "Must agree to SAFT");

        bool isGa;
        uint256 multi = 1;

        // First 8 hours is gauranteed allocation
        if (block.timestamp < dcbAgreement.startDate.add(8 hours)) {
            isGa = true;
            // second 8 hours is FCFS - 2x allocation
        } else if (block.timestamp < dcbAgreement.startDate.add(16 hours)) {
            multi = 2;
            // final 8 hours is Free for all - 10x allocation
        } else {
            multi = 10;
        }

        // Allocation of user
        uint256 alloc;

        if (isGa) {
            require(user.active, "User doesn't have any allocation");
            alloc = getUserAllocation(msg.sender);
        } else {
            (bool _flag, uint256 _tier, uint256 _multi) = tiers.getTierOfUser(msg.sender);
            if (_flag) {
                alloc = getAllocationForTier(uint8(_tier), uint8(_multi));
            }
        }

        // during FCFS users get multiplied allocation
        require(
            dcbAgreement.investorList[msg.sender].investAmount.add(_investFund) <= alloc.mul(multi),
            "Amount greater than allocation"
        );

        if (!dcbAgreement.investorList[msg.sender].active) {
            /**
             * add new investor to investor list for specific agreeement
             */
            dcbAgreement.investorList[msg.sender].wallet = msg.sender;
            dcbAgreement.investorList[msg.sender].investAmount = _investFund;
            dcbAgreement.investorList[msg.sender].joinDate = block.timestamp;
            dcbAgreement.investorList[msg.sender].active = true;
            _participants.push(msg.sender);
        }
        // user has already deposited so update the deposit
        else {
            dcbAgreement.investorList[msg.sender].investAmount =
                dcbAgreement.investorList[msg.sender].investAmount.add(_investFund);
        }

        dcbAgreement.totalInvestFund = dcbAgreement.totalInvestFund.add(_investFund);

        uint256 paymentDecimals = ERC20(address(dcbAgreement.token)).decimals();
        uint256 saleDecimals = ERC20(address(saleToken)).decimals();

        uint256 value = dcbAgreement.investorList[msg.sender].investAmount;
        uint256 numTokens = (value * 10 ** saleDecimals * dcbAgreement.totalTokenOnSale)
            / (dcbAgreement.hardcap * 10 ** paymentDecimals);

        investment.setUserInvestment(msg.sender, address(this), value);
        vesting.setCrowdfundingWhitelist(msg.sender, numTokens, value);

        emit NewInvestment(msg.sender, _investFund);

        return true;
    }

    /**
     *
     * @dev getter function for list of participants
     *
     * @return {uint256} return total participant count of crowdfunding
     *
     */
    function getParticipants() external view returns (address[] memory) {
        return _participants;
    }

    /**
     *
     * @dev getter function for list of registered users
     *
     * @return {address[]} return total participants registered for crowdfunding
     *
     */
    function getRegisteredUsers() external view returns (address[] memory) {
        return _registeredUsers;
    }

    function userInvestment(address _address) external view override returns (uint256 investAmount, uint256 joinDate) {
        investAmount = dcbAgreement.investorList[_address].investAmount;
        joinDate = dcbAgreement.investorList[_address].joinDate;
    }

    /**
     *
     * @dev getter function for ticket value of a tier
     *
     * @param _tier Tier value
     * @param _multi multiplier if applicable (default 1)
     *
     * @return return total participant count of crowdfunding
     *
     */
    function getAllocationForTier(uint8 _tier, uint8 _multi) public view returns (uint256) {
        return ((((2 ** _tier) * _multi).mul(dcbAgreement.hardcap)).div(totalShares));
    }

    /**
     *
     * @dev getter function for allocation of a user
     *
     * @param _address Address of the user
     *
     * @return return total participant count of crowdfunding
     *
     */
    function getUserAllocation(address _address) public view override returns (uint256) {
        return ((userAllocation[_address].shares.mul(dcbAgreement.hardcap)).div(totalShares));
    }

    /**
     *
     * @dev getter function for total participants
     *
     * @return {uint256} return total participant count of crowdfunding
     *
     */
    function getInfo() public view override returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            dcbAgreement.hardcap,
            dcbAgreement.createDate,
            dcbAgreement.startDate,
            dcbAgreement.endDate,
            dcbAgreement.totalInvestFund,
            _participants.length
        );
    }
}