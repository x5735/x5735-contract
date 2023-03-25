//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./library/EGoldUtils.sol";

import "../../interfaces/iEGoldMinerNFT.sol";
import "./interfaces/iEGoldIdentity.sol";
import "./interfaces/iEGoldMinerRegistry.sol";
import "./interfaces/iEGoldRank.sol";
import "./interfaces/iEGoldRate.sol";

contract EGoldTreasury3 is AccessControl , Pausable , ReentrancyGuard {
    using SafeMath for uint256;

    IEGoldIdentity public Identity;

    IEGoldMinerRegistry public MinerRegistry;

    IEGoldRank public Rank;

    IEGoldRate public Rate;

    IERC20 public Token;

    iEGoldMinerNFT public NFT;

    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    uint256 public MaxLevel;

    address public masterAddress;

    mapping ( address => uint256 ) private share;

    modifier isVaildClaim(uint256 _amt) {
        require(share[msg.sender] >= _amt);
        _;
    }

    modifier isVaildReferer(address _ref) {
        uint256 level = Identity.fetchRank(_ref);
        require(level != 0);
        _;
    }

    event puchaseEvent(
        address indexed _buyer,
        address indexed _referer,
        uint256 _minterType,
        uint256 _rate
    );

    event alloc(address indexed _address, uint256 _share);

    event claimEvent(address indexed _buyer, uint256 _value, uint256 _pendingShare);

    constructor ( address _identity , address _minerReg , address _rank ,  address _rate , address _master , uint256 _maxLevel , address _token , address _nft , address _DFA ) AccessControl() {
        _setupRole(DEFAULT_ADMIN_ROLE, _DFA);

        Identity = IEGoldIdentity(_identity);
        MinerRegistry = IEGoldMinerRegistry(_minerReg);
        Rank = IEGoldRank(_rank);
        Rate = IEGoldRate(_rate);
        Token = IERC20(_token);
        NFT = iEGoldMinerNFT(_nft);

        masterAddress = _master;
        MaxLevel = _maxLevel;
    }

    // Pause Function
    function pauseToken() external onlyRole(PAUSE_ROLE) returns (bool) {
        _pause();
        return true;
    }

    function unpauseToken() external onlyRole(PAUSE_ROLE) returns (bool) {
        _unpause();
        return true;
    }
    // Pause Function

    function LevelChange(address _addr) internal {
        uint256 curLevel = Identity.fetchRank(_addr);
        while (curLevel <= MaxLevel) {
            ( uint256 _sn , ) = Identity.fetchSales(_addr);
            if ( _sn < Rank.fetchRanklimit(curLevel) ){
                break;
            } else {
                Identity.setRank(_addr , curLevel);
            }
            curLevel = curLevel.add(1);
        }
    }

    function LoopFx(
        address _addr,
        uint256 _value0,
        uint256 _value,
        uint256 _shareRatio
    ) internal returns ( uint256 value ) {
        ( uint256 _sn , uint256 _sales ) = Identity.fetchSales(_addr );
        Identity.setSales(_addr , _sn + _value0  , _sales + _value0 );
        uint256 rankPercent = Rank.fetchRankPercent(Identity.fetchRank(_addr));
        if ( _shareRatio < rankPercent ) {
            uint256 diff = rankPercent - _shareRatio;
            share[_addr] = share[_addr] + _value.mul(diff).div(1000000);
            emit alloc( _addr , _value.mul(diff).div(1000000) );
            value = rankPercent;
        } else if ( _shareRatio == rankPercent ) {
            emit alloc(_addr, 0);
            value = rankPercent;
        }
        return value;
    }

    function iMint(address _addr, uint256 _type) internal {
        EGoldUtils.minerStruct memory minerInfo = MinerRegistry.fetchMinerInfo(_type);
        NFT.mint(_addr,  minerInfo.uri , minerInfo.name , minerInfo.hashRate, minerInfo.powerFactor);
    }

    function purchase(address _referer, uint256 _type)
        public
        whenNotPaused
        isVaildReferer(_referer)
        returns (bool)
    {
        address Parent;
        uint256 cut = 0;
        uint256 lx = 0;
        bool overflow = false;
        iMint(msg.sender, _type);

        uint256 amt = MinerRegistry.fetchMinerRate(_type);
        uint256 tokens = Rate.fetchRate(amt);
        Token.transferFrom(msg.sender, address(this) , tokens);
        if (Identity.fetchRank(msg.sender) == 0) {
            Identity.setRank(msg.sender, 1);
        }

        address iParent = Identity.fetchParent(msg.sender);
        if (iParent == address(0)) {
            Parent = _referer;
            Identity.setParent(msg.sender , Parent);
        } else {
            Parent = iParent;
        }
        while (lx < 500) {
            lx = lx.add(1);
            cut = LoopFx(Parent, amt * 1 ether , tokens ,  cut);
            LevelChange(Parent);
            address lParent = Identity.fetchParent(Parent);
            if (lParent == address(0)) {
                break;
            }
            Parent = Identity.fetchParent(lParent);
            if (lx == 250) {
                overflow = true;
            }
        }
        if (overflow) {
            cut = LoopFx(masterAddress, amt * 1 ether , tokens , cut);
        }
        emit puchaseEvent(msg.sender, iParent, _type , amt );
        return true;
    }

    function claim(uint256 _amt) external whenNotPaused isVaildClaim(_amt) returns (bool) {
        uint256 userShare = share[msg.sender];
        share[msg.sender] = userShare  - _amt;
        Token.transfer(msg.sender,_amt);
        emit claimEvent(msg.sender, _amt, share[msg.sender]);
        return true;
    }

    function fetchClaim( address _addr ) external view returns ( uint256 ){
        return share[_addr];
    }

}