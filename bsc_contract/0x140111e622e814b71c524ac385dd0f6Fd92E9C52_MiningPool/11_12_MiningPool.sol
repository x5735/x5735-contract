pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract MiningPool is Ownable, ERC1155Holder {
    using SafeMath for uint256;
    struct Stake {
        uint256 id;
        bool isStaking;
        uint256 createdAt;
        uint256 claimAt;
        uint256 claimAmount;
    }

    address public ADMIN_ADDRESS = 0x5f2192f495af8e4A102059379f46C596906690F2;
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public TOKEN = 0xf193182261760C739CE0e6aaB955FC7e21268201;
    address public NFT = 0xE27144e6A133609E7897b1d03C483A4a9Dd0Ec73;

    uint256 public REQUIRE_TOKEN_STAKING = 2000000000000000000000; // 2.000
    uint256 public REQUIRE_NFT_STAKING = 1; // 1

    uint256 public MAX_MINING_NFT_PHASE_1 = 16425000000000000000000; // 16425
    uint256 public MAX_MINING_NFT_PHASE_2 = 8212500000000000000000; // 8212.5
    uint256 public MAX_MINING_NFT_PHASE_3 = 4106250000000000000000; // 4106.25

    uint256 public MINING_PER_MINUTE_PHASE_1 = 31250000000000000; // 0.03125
    uint256 public MINING_PER_MINUTE_PHASE_2 = 15625000000000000; // 0.015625
    uint256 public MINING_PER_MINUTE_PHASE_3 = 7812500000000000; // 0.0078125

    uint256 public TOTAL_CLAIM = 0;
    uint256 public PHASE = 1;
    uint256 public ID = 1;
    bool public PAUSE_STAKING = false;
    mapping(uint256 => uint256) public TOTAL_STAKING_TOKEN;
    mapping(uint256 => uint256) public TOTAL_STAKING_NFT;

    mapping(address => mapping(uint256 => Stake)) public listStake;

    event STAKING_EVENT(
        uint256 id,
        address indexed user,
        uint256 phase,
        uint256 timestamp
    );
    event CLAIM_EVENT(
        uint256 id,
        address indexed user,
        uint256 phase,
        uint256 amount,
        uint256 timestamp
    );

    constructor() {}

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    function _checkAdmin() internal view virtual {
        require(
            ADMIN_ADDRESS == msg.sender,
            "Mining pool: caller is not the admin"
        );
    }

    function doStaking() public {
        Stake storage stakeDetail = listStake[msg.sender][PHASE];
        require(!PAUSE_STAKING, "Mining pool: stake is stopped");
        require(
            !stakeDetail.isStaking,
            "Mining pool: you are staking in this phase cannot stake again."
        );
        require(
            IERC20(TOKEN).allowance(address(msg.sender), address(this)) >=
                REQUIRE_TOKEN_STAKING,
            "Mining pool: not enough allowance."
        );
        require(
            IERC20(TOKEN).balanceOf(address(msg.sender)) >=
                REQUIRE_TOKEN_STAKING,
            "Mining pool: not enough token to staking."
        );
        require(
            IERC1155(NFT).isApprovedForAll(address(msg.sender), address(this)),
            "Mining pool: please approve NFT for contract."
        );

        require(
            IERC1155(NFT).balanceOf(address(msg.sender), 1) >=
                REQUIRE_NFT_STAKING,
            "Mining pool: not enough NFT to staking."
        );

        IERC20(TOKEN).transferFrom(
            msg.sender,
            DEAD_ADDRESS,
            REQUIRE_TOKEN_STAKING
        );
        IERC1155(NFT).safeTransferFrom(
            address(msg.sender),
            address(this),
            1,
            REQUIRE_NFT_STAKING,
            "0x00"
        );
        uint256 nowTimestamp = block.timestamp;
        stakeDetail.id = ID;
        stakeDetail.isStaking = true;
        stakeDetail.createdAt = nowTimestamp;
        stakeDetail.claimAt = nowTimestamp;

        emit STAKING_EVENT(ID, msg.sender, PHASE, nowTimestamp);

        TOTAL_STAKING_TOKEN[PHASE] += REQUIRE_TOKEN_STAKING;
        TOTAL_STAKING_NFT[PHASE]++;
        ID++;
    }

    function harvest(uint256 _phase) public returns (bool) {
        Stake storage stakeDetail = listStake[msg.sender][_phase];
        require(stakeDetail.isStaking, "You are not staking.");

        uint256 totalClaim = stakeDetail.claimAmount;
        uint256 mul = block.timestamp.sub(stakeDetail.claimAt).div(60);
        uint256 amountClaimToken = 0;
        bool refundNFT = false;

        if (_phase == 1) {
            amountClaimToken = MINING_PER_MINUTE_PHASE_1 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_1) {
                amountClaimToken = MAX_MINING_NFT_PHASE_1 - totalClaim;
                refundNFT = true;
            }
            if (amountClaimToken == MAX_MINING_NFT_PHASE_1) {
                refundNFT = true;
            }
        } else if (_phase == 2) {
            amountClaimToken = MINING_PER_MINUTE_PHASE_2 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_2) {
                amountClaimToken = MAX_MINING_NFT_PHASE_2 - totalClaim;
                refundNFT = true;
            }
            if (amountClaimToken == MAX_MINING_NFT_PHASE_2) {
                refundNFT = true;
            }
        } else {
            amountClaimToken = MINING_PER_MINUTE_PHASE_3 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_3) {
                amountClaimToken = MAX_MINING_NFT_PHASE_3 - totalClaim;
                refundNFT = true;
            }
            if (amountClaimToken == MAX_MINING_NFT_PHASE_3) {
                refundNFT = true;
            }
        }

        if (refundNFT) {
            IERC1155(NFT).safeTransferFrom(
                address(this),
                address(msg.sender),
                1,
                1,
                "0x00"
            );
        }

        require(
            amountClaimToken > 0,
            "Mining pool: you have finish this package"
        );
        require(
            IERC20(TOKEN).balanceOf(address(this)) >= amountClaimToken,
            "Mining pool: contract not enough balance"
        );

        IERC20(TOKEN).transfer(msg.sender, amountClaimToken);
        stakeDetail.claimAmount += amountClaimToken;
        stakeDetail.claimAt += 60 * mul;
        emit CLAIM_EVENT(
            stakeDetail.id,
            msg.sender,
            _phase,
            amountClaimToken,
            stakeDetail.claimAt
        );

        TOTAL_CLAIM += amountClaimToken;

        return true;
    }

    function amountCanHarvest(
        uint256 _phase,
        address _address
    ) public view returns (uint256) {
        Stake memory stakeDetail = listStake[_address][_phase];

        uint256 totalClaim = stakeDetail.claimAmount;
        uint256 mul = block.timestamp.sub(stakeDetail.claimAt).div(60);
        uint256 amountClaimToken = 0;
        if (_phase == 1) {
            amountClaimToken = MINING_PER_MINUTE_PHASE_1 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_1) {
                amountClaimToken = MAX_MINING_NFT_PHASE_1 - totalClaim;
            }
        } else if (_phase == 2) {
            amountClaimToken = MINING_PER_MINUTE_PHASE_2 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_2) {
                amountClaimToken = MAX_MINING_NFT_PHASE_2 - totalClaim;
            }
        } else {
            amountClaimToken = MINING_PER_MINUTE_PHASE_3 * mul;
            if (totalClaim + amountClaimToken > MAX_MINING_NFT_PHASE_3) {
                amountClaimToken = MAX_MINING_NFT_PHASE_3 - totalClaim;
            }
        }
        return amountClaimToken;
    }

    function setTokenContract(address _address) public onlyAdmin {
        TOKEN = _address;
    }

    function setNFTContract(address _address) public onlyAdmin {
        NFT = _address;
    }

    function setPauseStaking(bool _result) public onlyAdmin {
        PAUSE_STAKING = _result;
    }

    function setPhase(uint256 _phase) public onlyAdmin {
        PHASE = _phase;
    }

    function setAdminAddress(address _address) public onlyAdmin {
        ADMIN_ADDRESS = _address;
    }

    function setRequireStake(
        uint256 _amountToken,
        uint256 _amountNft
    ) public onlyAdmin {
        REQUIRE_TOKEN_STAKING = _amountToken;
        REQUIRE_NFT_STAKING = _amountNft;
    }

    function setMiningPhase1(
        uint256 _miningPerMin,
        uint256 _maxMining
    ) public onlyAdmin {
        MINING_PER_MINUTE_PHASE_1 = _miningPerMin;
        MAX_MINING_NFT_PHASE_1 = _maxMining;
    }

    function setMiningPhase2(
        uint256 _miningPerMin,
        uint256 _maxMining
    ) public onlyAdmin {
        MINING_PER_MINUTE_PHASE_2 = _miningPerMin;
        MAX_MINING_NFT_PHASE_2 = _maxMining;
    }

    function setMiningPhase3(
        uint256 _miningPerMin,
        uint256 _maxMining
    ) public onlyAdmin {
        MINING_PER_MINUTE_PHASE_3 = _miningPerMin;
        MAX_MINING_NFT_PHASE_3 = _maxMining;
    }
}