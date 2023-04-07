// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IESBT.sol";
import "../data/DataStore.sol";
import "../utils/interfaces/INFTUtils.sol";


interface IAcitivity {
    function updateCompleteness(address _account) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
}

interface ShaHld {
    function getReferalState(address _account) external view returns (uint256, uint256[] memory, address[] memory , uint256[] memory, bool[] memory);
}

interface IDataStore{
    function getAddressSetCount(bytes32 _key) external view returns (uint256);
    function getAddressSetRoles(bytes32 _key, uint256 _start, uint256 _end) external view returns (address[] memory);
    function getAddUint(address _account, bytes32 key) external view returns (uint256);
    function getUint(bytes32 key) external view returns (uint256);
    function getAddMpAddressSetRoles(address _mpaddress, bytes32 _key, uint256 _start, uint256 _end) external view returns (address[] memory);

}



contract ESBTRouter is ReentrancyGuard, Ownable, DataStore{
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;

    bytes32 public constant REFERRAL_PARRENT = keccak256("REFERRAL_PARRENT");
    bytes32 public constant REFERRAL_CHILD = keccak256("REFERRAL_CHILD");
    bytes32 public constant ACCUM_POSITIONSIZE = keccak256("ACCUM_POSITIONSIZE");
    bytes32 public constant ACCUM_SWAP = keccak256("ACCUM_SWAP");
    bytes32 public constant ACCUM_ADDLIQUIDITY = keccak256("ACCUM_ADDLIQUIDITY");
    bytes32 public constant ACCUM_SCORE = keccak256("ACCUM_SCORE");
    bytes32 public constant TIME_SOCRE_DEC= keccak256("TIME_SOCRE_DEC");
    bytes32 public constant TIME_RANK_UPD = keccak256("TIME_RANK_UPD");

    bytes32 public constant VALID_VAULTS = keccak256("VALID_VAULTS");
    bytes32 public constant VALID_LOGGER = keccak256("VALID_LOGGER");
    bytes32 public constant VALID_SCORE_UPDATER = keccak256("VALID_SCORE_UPDATER");
    bytes32 public constant ACCUM_FEE_DISCOUNTED = keccak256("ACCUM_FEE_DISCOUNTED");
    bytes32 public constant ACCUM_FEE_REBATED = keccak256("ACCUM_FEE_REBATED");
    bytes32 public constant ACCUM_FEE_REBATED_CLAIMED = keccak256("ACCUM_FEE_REBATED_CLAIMED");
    bytes32 public constant ACCUM_FEE_DISCOUNTED_CLAIMED = keccak256("ACCUM_FEE_DISCOUNTED_CLAIMED");
    bytes32 public constant ACCUM_FEE = keccak256("ACCUM_FEE");
    bytes32 public constant MIN_MINT_TRADING_VALUE = keccak256("MIN_MINT_TRADING_VALUE");
    bytes32 public constant INTERVAL_RANK_UPDATE = keccak256("INTERVAL_RANK_UPDATE");
    bytes32 public constant INTERVAL_SCORE_UPDATE = keccak256("INTERVAL_SCORE_UPDATE");
    bytes32 public constant ONLINE_ACTIVITIE = keccak256("ONLINE_ACTIVITIE");
   
    uint256 public constant FEE_PERCENT_PRECISION = 10 ** 6;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USD_TO_SCORE_PRECISION = 10 ** 12;
    uint256 public constant SCORE_DECREASE_PRECISION = 10 ** 18;
    uint256 constant private PRECISION_COMPLE = 10000;
    uint256 public constant SCORE_PRECISION = 10 ** 18;


    event RankUpdate(address _account, uint256 _rankP, uint256 _rankA);
    event UpdateFee(address _account, uint256 _origFee, uint256 _discountedFee, address _parent, uint256 _rebateFee);

    mapping(address => bytes32) public loggerDef;
    mapping(uint256 => uint256) public scorePara;
    uint256[] public scoreToRank;


    address public gEDE;
    address public esbtPersonal;
    address public esbtContract;

    constructor( ) {
        //set default:
        // scorePara[10000] = 0;//gEdeBalance for Rank E
        // scorePara[10001] = 0;//gEdeBalance for Rank D
        // scorePara[10002] = 0;//gEdeBalance for Rank C
        // scorePara[10003] = 0;//gEdeBalance for Rank B
        // scorePara[10004] = 1000 * 1e18;//gEdeBalance for Rank A
        scorePara[10005] = 5000 * 1e18;//gEdeBalance for Rank S
        scorePara[10006] = 10000 * 1e18;//gEdeBalance for Rank SS
    }

    modifier onlyScoreUpdater() {
        require(hasAddressSet(VALID_SCORE_UPDATER, msg.sender), "unauthorized updater");
        _;
    }

    ///--------------------- Owner setting ---------------------
    function setScorePara(uint256 _id, uint256 _value) public onlyOwner {
        scorePara[_id] = _value;
    }

    function setScoreToRank(uint256[] memory _minValue) external onlyOwner{
        require(_minValue.length > 3 && _minValue[0] == 0, "invalid score-rank setting");
        scoreToRank = _minValue;
    }

    function setgEdeYieldDistributor(address _gEDE) public onlyOwner {
        gEDE = _gEDE;
    }

    function setESBT(address _esbtPersonal, address _esbtContract) public onlyOwner {
        esbtPersonal = _esbtPersonal;
        esbtContract = _esbtContract;
    }

    function setUintValue(bytes32 _bIdx, uint256 _value) public onlyOwner {
        setUint(_bIdx, _value);
    }

    function setUintValueByString(string memory _strIdx, uint256 _value) public onlyOwner {
        setUint(keccak256(abi.encodePacked(_strIdx)), _value);
    }

    function setScoreUpdater(address _updater, bool _status) external onlyOwner {
        if (_status){
            safeGrantAddressSet(VALID_SCORE_UPDATER, _updater);
            _setLogger(_updater, true);
        }
        else{
            safeRevokeAddressSet(VALID_SCORE_UPDATER, _updater);
            _setLogger(_updater, false);
        }
    }

    function setVault(address _vault, bool _status) external onlyOwner {
        if (_status){
            grantAddressSet(VALID_VAULTS, _vault);
            loggerDef[_vault] = keccak256(abi.encodePacked("VALID_LOGGER", _vault));
            _setLogger(_vault, true);
        }
        else{
            revokeAddressSet(VALID_VAULTS, _vault);
            _setLogger(_vault, false);
        }
    }





    ///--------------------- public view ---------------------
    function userClaimable(address _account) public view returns (uint256, uint256){
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return (0, 0);
        uint256 oriESBT_rebated = IDataStore(esbt).getAddUint(_account, ACCUM_FEE_REBATED).sub(
            IDataStore(esbt).getAddUint(_account, ACCUM_FEE_REBATED_CLAIMED) );
        uint256 oriESBT_disc = IDataStore(esbt).getAddUint(_account, ACCUM_FEE_DISCOUNTED).sub(
            IDataStore(esbt).getAddUint(_account, ACCUM_FEE_DISCOUNTED_CLAIMED) );
        return (oriESBT_rebated.add(getAddUint(_account, ACCUM_FEE_REBATED).sub(getAddUint(_account, ACCUM_FEE_REBATED_CLAIMED))),
                oriESBT_disc.add(getAddUint(_account, ACCUM_FEE_DISCOUNTED).sub(getAddUint(_account, ACCUM_FEE_DISCOUNTED_CLAIMED))));
    }

    function getUsergEdeBalance(address _account) public view returns (uint256){
        if (gEDE == address(0)) return 0;
        return IAcitivity(gEDE).balanceOf(_account);
    }

    function rank(address _account) public view returns (uint256) {
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return 0;
        uint256 _rankRes = IESBT(esbt).rank(_account);
        if (gEDE == address(0)) return _rankRes;
        uint256 _gEdeBalance = IAcitivity(gEDE).balanceOf(_account);
        //get max rank by gEdeBalance
        uint256 _gMaxRank = scoreToRank.length;
        for(uint256 i = 1; i < scoreToRank.length; i++){
            if (_gEdeBalance < scorePara[10000 + i]){
                _gMaxRank = i;
                break;
            }
        }
        return _rankRes > _gMaxRank ? _gMaxRank : _rankRes; 
    }


    function updateFee(address _account, uint256 _origFee) external returns (uint256){
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return 0;
        address _vault = msg.sender;
        _validLogger(_vault);
        if (!hasAddressSet(VALID_VAULTS, _vault)) return 0;
        if (IAcitivity(esbt).balanceOf(_account)!= 1) return 0;

        (address[] memory _par, ) = IESBT(esbt).getReferralForAccount(_account);
        if (_par.length != 1) return 0;
        (uint256 dis_per,  ) = IESBT(esbt).rankToDiscount(rank(_account));
        ( , uint256 reb_per) = IESBT(esbt).rankToDiscount(rank(_par[0]));

        uint256 _discountedFee = _origFee.mul(dis_per).div(FEE_PERCENT_PRECISION);
        uint256 _rebateFee = _origFee.mul(reb_per).div(FEE_PERCENT_PRECISION);
        if (_rebateFee.add(_discountedFee) >= _origFee){
            _rebateFee = 0;
            _discountedFee = 0;
        }
        incrementAddUint(_account, ACCUM_FEE_DISCOUNTED, _discountedFee);
        // incrementAddUint(_account, tradingKey[_vault][ACCUM_FEE], _origFee);
        address _parent = IDataStore(esbt).getAddMpAddressSetRoles(_account, REFERRAL_PARRENT, 0, 1)[0];
        incrementAddUint(_parent, ACCUM_FEE_REBATED, _rebateFee);
        emit UpdateFee(_account, _origFee, _discountedFee, _parent, _rebateFee);
        return _discountedFee.add(_rebateFee);
    }

    function updateClaimVal(address _account) external onlyScoreUpdater  {
        setAddUint(_account, ACCUM_FEE_REBATED_CLAIMED,  getAddUint(_account, ACCUM_FEE_REBATED));
        setAddUint(_account, ACCUM_FEE_DISCOUNTED_CLAIMED,  getAddUint(_account, ACCUM_FEE_DISCOUNTED));
    }


    function updateScoreForAccount(address _account, address _vault, uint256 _amount, uint256 _reasonCode) external onlyScoreUpdater {
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return ;
        IESBT(esbt).updateScoreForAccount(_account,  _vault,  _amount,  _reasonCode);
    }

    function updateTradingScoreForAccount(address _account, address _vault, uint256 _amount, uint256 _refCode) external onlyScoreUpdater {
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return ;
       IESBT(esbt).updateTradingScoreForAccount(_account,  _vault,  _amount,  _refCode);
    }

    function updateSwapScoreForAccount(address _account, address _vault, uint256 _amount) external onlyScoreUpdater{
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return ;
        IESBT(esbt).updateSwapScoreForAccount(_account,  _vault,  _amount);
    }

    function updateAddLiqScoreForAccount(address _account, address _vault, uint256 _amount, uint256 _refCode) external onlyScoreUpdater {
        address esbt =_getESBT(_account);
        if (esbt == address(0)) return ;
        IESBT(esbt).updateAddLiqScoreForAccount(_account,  _vault,  _amount,_refCode);
    }

    //================= Internal Functions =================
    function _setLogger(address _account, bool _status) internal {
        if (_status && !hasAddressSet(loggerDef[_account], _account))
            grantAddressSet(loggerDef[_account],  _account);
        else if (!_status && hasAddressSet(loggerDef[_account], _account))
            revokeAddressSet(loggerDef[_account],  _account);
    }

    function _validLogger(address _account) internal view {
        require(hasAddressSet(loggerDef[_account], _account), "invalid logger");
    }

    function _getESBT(address _account) internal view returns(address){
        address esbt = address(0) ;
        if (esbtPersonal != address(0) && IERC721(esbtPersonal).balanceOf(_account) == 1)
            esbt = esbtPersonal;
        else if (esbtContract != address(0) && IERC721(esbtContract).balanceOf(_account) == 1)
            esbt = esbtContract;
        return esbt;
    }


    function getInvitedUser(address _ESBT, address _account) public view returns (address[] memory, uint256[] memory) {
        (, address[] memory childs) = IESBT(_ESBT).getReferralForAccount(_account);
        uint256[] memory infos = new uint256[](childs.length*3);

        for (uint256 i =0; i < childs.length; i++){
            infos[i*3] = IESBT(_ESBT).createTime(childs[i]);
            infos[i*3 + 1] = IESBT(_ESBT).userSizeSum(childs[i]);
            infos[i*3 + 2] = IESBT(_ESBT).getScore(childs[i]);
        }
        return (childs, infos);
    }

    function getBasicInfo(address /*_ESBT*/, address _account) public view returns (string[] memory, address[] memory, uint256[] memory) {
        uint256[] memory infos = new uint256[](17);
        string[] memory infosStr = new string[](2);
        address[] memory _emptyChd = new address[](0);
        address _ESBT =_getESBT(_account);
        if (_ESBT == address(0)) return (infosStr, _emptyChd, infos);
        
        (, address[] memory childs) = IESBT(_ESBT).getReferralForAccount(_account);

        (infos[0], infos[1]) = IESBT(_ESBT).accountToDisReb(_account);
        infos[2] = IESBT(_ESBT).userSizeSum(_account);
        infos[3] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_SWAP);
        infos[4] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_ADDLIQUIDITY);
        infos[5] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_POSITIONSIZE);
        infos[6] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_FEE_DISCOUNTED);
        infos[7] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_FEE); 
        infos[8] = IDataStore(_ESBT).getAddUint(_account,  ACCUM_FEE_REBATED); 
        infos[9] = IESBT(_ESBT).getScore(_account);
        infos[10] = rank(_account);
        infos[11] = IESBT(_ESBT).createTime(_account);
        infos[12] = IESBT(_ESBT).addressToTokenID(_account);

        infos[13] = IDataStore(_ESBT).getUint(INTERVAL_RANK_UPDATE);
        infos[14] = IDataStore(_ESBT).getUint(INTERVAL_SCORE_UPDATE);

        infos[15] = IDataStore(_ESBT).getAddUint(_account, TIME_RANK_UPD).add(infos[13]);
        infos[15] = infos[15] > infos[13] ? infos[15] : 0; 
        infos[16] = IDataStore(_ESBT).getAddUint(_account, TIME_SOCRE_DEC).add(infos[14]);
        infos[16] = infos[16] > infos[14] ? infos[16] : 0; 

        infosStr[0] = IESBT(_ESBT).nickName(_account);
        infosStr[1] = IESBT(_ESBT).getRefCode(_account);
        return (infosStr, childs, infos);
    }


    function needUpdate(address _shareAct, address _account) public view returns (uint256) {
        (uint256 _refNum, uint256[] memory _compList, address[] memory _userList, , ) = ShaHld(_shareAct).getReferalState(_account);

        if (_refNum == _userList.length) return 0;

        uint256 needUpd = 1;
        for (uint256 i = 0; i < _compList.length; i++){
            if (_compList[i] < PRECISION_COMPLE){
                needUpd = i + 1;
                break;
            }
        }
        return needUpd;
    }   

}