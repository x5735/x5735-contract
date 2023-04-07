// SPDX-License-Identifier: MIT

//** DCB Token claim Contract */
//** Author: Aceson 2022.3 */

pragma solidity 0.8.19;

import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IDCBInvestments.sol";
import "./interfaces/IDCBTiers.sol";
import "./interfaces/IDCBWalletStore.sol";
import "./interfaces/IDCBPlatformVesting.sol";

contract DCBTokenClaim is Initializable {
    using SafeMath for uint256;
    using SafeMath for uint8;

    struct UserAllocation {
        uint256 shares; //Shares owned by user
        uint8 registeredTier; //Tier of user while registering
        bool active; //Is active or not
        uint256 claimedAmount; //Claimed amount from event
    }

    struct ClaimInfo {
        uint8 minTier; //Minimum tier required for users while registering
        uint32 createDate; //Created date
        uint32 startDate; //Event start date
        uint32 endDate; //Event end date
        uint256 distAmount; //Total distributed amount
    }

    struct Tiers {
        uint256 minLimit; //Minimum amount to be held for reaching this tier
        uint16 multi; //Multiplier for this tier.
            //If multiplier is 10%, input 1100 (1100 / 1000 = 1.1x = 10%)
    }

    struct Params {
        address rewardTokenAddr;
        address walletStoreAddr;
        address vestingAddr;
        bytes32 answerHash;
        address tiersAddr;
        uint256 distAmount;
        uint8 minTier;
        uint32 startDate;
        uint32 endDate;
        Tiers[] tiers;
    }

    IDCBTiers private _tiers; //Tiers contract
    IDCBWalletStore private _walletStore; //Walletstore contract
    IDCBInvestments private _investment; //Investments contract
    IERC20 private _rewardToken; //Token to be used for tier calc
    IDCBPlatformVesting public _vesting; //Vesting contract

    //Keccack(<hidden answer>)

    /* solhint-disable var-name-mixedcase */
    bytes32 public ANSWER_HASH;

    uint256 public totalShares; //Total shares for the event

    mapping(address => UserAllocation) public userAllocation; //Allocation per user

    ClaimInfo public claimInfo;
    Tiers[] public tierInfo;

    address[] private participants;
    address[] private registeredUsers;

    event Initialized(Params p);
    event UserRegistered(address user);
    event UserClaimed(address user, uint256 amount);

    function initialize(Params memory p) external initializer {
        _walletStore = IDCBWalletStore(p.walletStoreAddr);
        _investment = IDCBInvestments(msg.sender);
        _tiers = IDCBTiers(p.tiersAddr);
        _rewardToken = IERC20(p.rewardTokenAddr);
        _vesting = IDCBPlatformVesting(p.vestingAddr);

        /**
         * Generate the new Claim Event
         */
        claimInfo.minTier = p.minTier;
        claimInfo.distAmount = p.distAmount;
        claimInfo.createDate = uint32(block.timestamp);
        claimInfo.startDate = p.startDate;
        claimInfo.endDate = p.endDate;

        ANSWER_HASH = p.answerHash;

        for (uint256 i = 0; i < p.tiers.length; i++) {
            tierInfo.push(Tiers({ minLimit: p.tiers[i].minLimit, multi: p.tiers[i].multi }));
        }

        emit Initialized(p);
    }

    function registerForAllocation(bytes memory _sig) external returns (bool) {
        address user = ECDSA.recover(ECDSA.toEthSignedMessageHash(ANSWER_HASH), _sig);
        require(msg.sender == user, "Invalid signer");

        (, uint256 _tier, uint256 _multi) = _tiers.getTierOfUser(msg.sender);

        require(_tier >= claimInfo.minTier, "Minimum tier required");
        require(_walletStore.isVerified(msg.sender), "User is not verified");
        require(!userAllocation[msg.sender].active, "Already registered");
        require(block.timestamp <= claimInfo.endDate && block.timestamp >= claimInfo.startDate, "Registration closed");

        uint256 shares = (2 ** _tier) * _multi;
        (, uint16 _holdMulti) = getTier(msg.sender);
        shares = shares.mul(_holdMulti).div(1000);

        userAllocation[msg.sender].active = true;
        userAllocation[msg.sender].shares = shares;
        userAllocation[msg.sender].registeredTier = uint8(_tier);

        registeredUsers.push(msg.sender);

        totalShares = totalShares.add(shares);
        emit UserRegistered(msg.sender);

        return true;
    }

    function claimTokens() external returns (bool) {
        UserAllocation storage user = userAllocation[msg.sender];

        require(user.active, "Not registered / Already claimed");
        require(block.timestamp >= claimInfo.endDate, "Claim not open yet");

        uint256 amount = getClaimableAmount(msg.sender);

        if (amount > 0) {
            participants.push(msg.sender);
            _investment.setUserInvestment(msg.sender, address(this), amount);
            _vesting.setTokenClaimWhitelist(msg.sender, amount);
        }

        user.shares = 0;
        user.claimedAmount = amount;
        user.active = false;

        emit UserClaimed(msg.sender, amount);

        return true;
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getRegisteredUsers() external view returns (address[] memory) {
        return registeredUsers;
    }

    function getClaimForTier(uint8 _tier, uint8 _multi) public view returns (uint256) {
        return (((2 ** _tier) * _multi.mul(claimInfo.distAmount)).div(totalShares));
    }

    function getClaimableAmount(address _address) public view returns (uint256) {
        return ((userAllocation[_address].shares.mul(claimInfo.distAmount)).div(totalShares));
    }

    function getTier(address _user) public view returns (uint256 _tier, uint16 _holdMulti) {
        uint256 len = tierInfo.length;
        uint256 amount = _rewardToken.balanceOf(_user);

        for (uint256 i = len - 1; i >= 0; i--) {
            if (amount >= tierInfo[i].minLimit) {
                return (i, tierInfo[i].multi);
            }
        }
    }
}