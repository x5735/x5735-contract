pragma solidity =0.5.16;

import "./interfaces/IERC20.sol";
import "./interfaces/IBrewlabsPair.sol";
import "./interfaces/IBrewlabsFeeManager.sol";
import "./libraries/SafeMath.sol";
import "./libraries/ReentrancyGuard.sol";
import "./libraries/BrewlabsLibrary.sol";

contract BrewlabsFeeManager is IBrewlabsFeeManager, ReentrancyGuard {
    using SafeMath for uint256;

    address private admin;
    address private factory;

    struct FeeDistribution {
        uint256 lpFee;
        uint256 brewlabsFee;
        uint256 tokenOwnerFee;
        uint256 tokenHolderFee;
        uint256 referralFee;
    }

    struct LPStakingInfo {
        uint256 lpSupply; // total LP token supply
        uint256 accRewards0;
        uint256 accRewards1;
        address[] lpStakersArray; // list of lp holder
        mapping(address => uint256) lpStaked; // keep lp balance of lp holders
        mapping(address => uint256) rewardsTable0; // last updated token0 rewards for lp holders
        mapping(address => uint256) rewardsTable1; // last updated token1 rewards for lp holders
    }

    struct Pool {
        address token0;
        address token1;
        address token0Owner;
        address token1Owner;
        LPStakingInfo lpStakingInfo;
        FeeDistribution feeDistribution;
        address referrer;
        mapping(address => uint256) balanceOfLpProvider; // fee token balance assigned to lp holders
        mapping(address => uint256) balanceOfBrewlabs; // fee token balance assigned to brewlabs treasury
        mapping(address => uint256) balanceOfTokenOwner; // fee token balance assigned to token owner
        mapping(address => uint256) balanceOfTokenHolder; // fee token balance assigned to token holder (similar to reflections)
        mapping(address => uint256) balanceOfReferral; // fee token balance assigned to stakers of referral contract
        mapping(address => uint256) totalBalance;
        uint timeToOpen;
    }

    mapping(address => Pool) private pools;
    address[] public pairs;
    address private brewlabsFeeTo; // brewlabs protocol fee treasury

    modifier onlyAdmin() {
        require(msg.sender == admin, "BrewlabsFeeManager: FORBIDDEN");
        _;
    }

    modifier validPair(
        address pair,
        address token0,
        address token1
    ) {
        require(
            pair == BrewlabsLibrary.pairFor(factory, token0, token1),
            "BrewlabsFeeManager: INVALID PAIR"
        );
        _;
    }

    modifier existPair(address pair) {
        bool exist = false;
        for (uint i; i < pairs.length; i++) {
            exist = exist || pairs[i] == pair;
        }
        require(exist == true, "BrewlabsFeeManager: PAIR DOESN'T EXIST");
        _;
    }

    constructor(address _factory, address _brewlabsFeeTo) public {
        admin = msg.sender;
        factory = _factory;
        brewlabsFeeTo = _brewlabsFeeTo;
    }

    function setBrewlabsFeeTo(address _brewlabsFeeTo) external onlyAdmin {
        brewlabsFeeTo = _brewlabsFeeTo;
    }

    function setFeeDistribution(
        address pair,
        bytes calldata feeDistribution
    ) external onlyAdmin {
        require(
            block.timestamp < pools[pair].timeToOpen,
            "BrewlabsFeeManager: AFTER THE POOL OPENED, UNABLE TO CHANGE FEE"
        );
        _setFeeDistribution(pair, feeDistribution);
    }

    function pendingLPRewards(
        address pair,
        address staker
    ) public view returns (uint amount0, uint amount1) {
        LPStakingInfo storage lpStakingInfo = pools[pair].lpStakingInfo;
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        uint256 balance0 = pools[pair].balanceOfLpProvider[token0];
        uint256 balance1 = pools[pair].balanceOfLpProvider[token1];
        uint256 lpBalance = IBrewlabsPair(pair).balanceOf(staker);
        uint256 leftOver0 = balance0 - lpStakingInfo.accRewards0;
        uint256 leftOver1 = balance1 - lpStakingInfo.accRewards1;
        amount0 =
            lpStakingInfo.rewardsTable0[staker] +
            leftOver0.mul(lpBalance).div(lpStakingInfo.lpSupply);
        amount1 =
            lpStakingInfo.rewardsTable1[staker] +
            leftOver1.mul(lpBalance).div(lpStakingInfo.lpSupply);
    }

    /**
     * @dev initialize pool for the pair represented by token0 and token1, which wil keep
     * fee balance coming from the pair. this should be called by factory at the time of lp creation
     * @param token0 token0 address of lp pair
     * @param token1 token1 address of lp pair
     * @param feeDistribution struct containing fee portion value for each fee categories.
     * (lpfee, brewlabsfee, tokenownerfee, tokenholderfee, referralfee)
     */
    function createPool(
        address token0,
        address token1,
        bytes calldata feeDistribution
    ) external {
        require(msg.sender == factory, "BrewlabsFeeManager: FORBIDDEN");
        address pair = BrewlabsLibrary.pairFor(factory, token0, token1);
        pools[pair].token0 = token0;
        pools[pair].token1 = token1;

        _setFeeDistribution(pair, feeDistribution);

        pools[pair].timeToOpen = block.timestamp + 3600 * 24;

        pairs.push(pair);
    }

    /**
     * @dev update fee rewarding stats based on new minted lp token amount
     * this should be called by pair token contract at the time of minting lp token
     * @param to liquidity provider the lp newly being minted to
     * @param token0 token0 address of lp pair
     * @param token1 token1 address of lp pair
     * @param pair caller - lp pair token address
     */
    function lpMinted(
        address to,
        address token0,
        address token1,
        address pair
    ) external validPair(pair, token0, token1) {
        _updateLPRewardsTable(pair);
        _updateStakedLP(pair, to);
        _updateLPSupply(pair);
    }

    /**
     * @dev update lp fee rewarding stats based on burnt lp token
     * this should be called by pair token contract at the time of burning lp token
     * @param from liquidity provider the lp being burnt from
     * @param token0 token0 address of lp pair
     * @param token1 token1 address of lp pair
     * @param pair caller - lp pair token address
     */
    function lpBurned(
        address from,
        address token0,
        address token1,
        address pair
    ) external validPair(pair, token0, token1) {
        _updateLPRewardsTable(pair);
        _updateStakedLP(pair, from);
        if (pools[pair].lpStakingInfo.lpStaked[from] == 0) {
            __claimLPFee(pair, from);
        }
        _updateLPSupply(pair);
    }

    /**
     * @dev update lp fee rewarding stats based on transfer transaction details
     * this should be called by pair token contract at the time of lp token transfer
     * @param from lp sender
     * @param to lp receiver
     * @param token0 token0 address of lp pair
     * @param token1 token1 address of lp pair
     * @param pair caller - lp pair token address
     */
    function lpTransferred(
        address from,
        address to,
        address token0,
        address token1,
        address pair
    ) external validPair(pair, token0, token1) {
        _updateLPRewardsTable(pair);
        _updateStakedLP(pair, from);
        _updateStakedLP(pair, to);
    }

    /**
     * @dev deposit fee token from pair at the time of user trading.
     * @param pair fee token resource
     * @param token fee token address
     * @param amount fee token amount being deposited
     */
    function notifyRewardAmount(
        address pair,
        address token,
        uint amount
    ) external existPair(pair) {
        require(
            token == pools[pair].token0 || token == pools[pair].token1,
            "BrewlabsFeeManager: INVALID TOKEN DEPOSIT"
        );
        require(amount > 0, "Brewlabs LP Farm: INSUFFICIENT REWARD AMOUNT");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint lpFee = pools[pair].feeDistribution.lpFee;
        uint brewlabsFee = pools[pair].feeDistribution.brewlabsFee;
        uint tokenOwnerFee = pools[pair].feeDistribution.tokenOwnerFee;
        uint tokenHolderFee = pools[pair].feeDistribution.tokenHolderFee;
        uint referralFee = pools[pair].feeDistribution.referralFee;

        uint totalFee = lpFee +
            brewlabsFee +
            tokenOwnerFee +
            tokenHolderFee +
            referralFee;
        pools[pair].balanceOfLpProvider[token] += amount.mul(lpFee).div(
            totalFee
        );
        pools[pair].balanceOfBrewlabs[token] += amount.mul(brewlabsFee).div(
            totalFee
        );
        pools[pair].balanceOfTokenOwner[token] += amount.mul(tokenOwnerFee).div(
            totalFee
        );
        pools[pair].balanceOfTokenHolder[token] += amount
            .mul(tokenHolderFee)
            .div(totalFee);
        pools[pair].balanceOfReferral[token] += amount.mul(referralFee).div(
            totalFee
        );
        pools[pair].totalBalance[token] += amount;
    }

    /**
     @dev claim all relevant fee from the pair including lpfee, 
     brewlabsfee, tokenownerfee, tokenholderfee and referralfee
     @param pair brewlabs pair address represent the pool in which keeping fee
     */
    function claim(address pair) public nonReentrant existPair(pair) {
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        uint totalBalance0BeforeClaim = pools[pair].totalBalance[token0];
        uint totalBalance1BeforeClaim = pools[pair].totalBalance[token1];

        _claimTokenHolderFee(pair, msg.sender);
        _claimLPFee(pair, msg.sender);
        if (msg.sender == brewlabsFeeTo) {
            _claimBrewlabsFee(pair);
        }
        if (msg.sender == pools[pair].referrer) {
            _claimReferralFee(pair);
        }
        if (msg.sender == pools[pair].token0Owner) {
            _claimTokenOwnerFee(pair, msg.sender, pools[pair].token0);
        }
        if (msg.sender == pools[pair].token1Owner) {
            _claimTokenOwnerFee(pair, msg.sender, pools[pair].token1);
        }
        uint totalBalance0AfterClaim = pools[pair].totalBalance[token0];
        uint totalBalance1AfterClaim = pools[pair].totalBalance[token1];

        emit Claimed(
            msg.sender,
            pair,
            totalBalance0AfterClaim - totalBalance0BeforeClaim,
            totalBalance1AfterClaim - totalBalance1BeforeClaim
        );
    }

    /**
     @dev claim fees from multiple pairs at a time
     @param brewlabs_pairs array of brewlabs pairs' address represent the pools in which keepinng fee
     */
    function claimAll(address[] calldata brewlabs_pairs) external nonReentrant {
        require(
            brewlabs_pairs.length > 0,
            "BrewlabsFeeManager: NOWHERE TO CLAIM FROM"
        );
        for (uint i; i < brewlabs_pairs.length; i++) {
            claim(brewlabs_pairs[i]);
        }
    }

    function _setFeeDistribution(
        address pair,
        bytes memory feeDistribution
    ) internal {
        (
            uint _lpFee,
            uint _brewlabsFee,
            uint _tokenOwnerFee,
            address _token0Owner,
            address _token1Owner,
            uint _tokenHolderFee,
            address _tokenForHolderFee,
            uint _referralFee,
            address _referrer
        ) = abi.decode(
                feeDistribution,
                (
                    uint,
                    uint,
                    uint,
                    address,
                    address,
                    uint,
                    address,
                    uint,
                    address
                )
            );
        pools[pair].feeDistribution.lpFee = _lpFee;
        pools[pair].feeDistribution.brewlabsFee = _brewlabsFee;
        pools[pair].feeDistribution.tokenOwnerFee = _tokenOwnerFee;
        pools[pair].feeDistribution.tokenHolderFee = _tokenHolderFee;
        pools[pair].feeDistribution.referralFee = _referralFee;

        if (_referrer != address(0)) pools[pair].referrer = _referrer;
        if (_token0Owner != address(0)) pools[pair].token0Owner = _token0Owner;
        if (_token1Owner != address(0)) pools[pair].token0Owner = _token1Owner;
    }

    function _updateStakedLP(address pair, address to) internal {
        uint lpBalance = IBrewlabsPair(pair).balanceOf(to);
        if (pools[pair].lpStakingInfo.lpStaked[to] == 0 && lpBalance > 0) {
            pools[pair].lpStakingInfo.lpStakersArray.push(to);
        }
        if (pools[pair].lpStakingInfo.lpStaked[to] > 0 && lpBalance == 0) {
            uint length = pools[pair].lpStakingInfo.lpStakersArray.length;
            for (uint i; i < length; i++) {
                if (to == pools[pair].lpStakingInfo.lpStakersArray[i]) {
                    pools[pair].lpStakingInfo.lpStakersArray[i] = pools[pair]
                        .lpStakingInfo
                        .lpStakersArray[length - 1];
                    pools[pair].lpStakingInfo.lpStakersArray.pop();
                    break;
                }
            }
        }
        pools[pair].lpStakingInfo.lpStaked[to] = lpBalance;
    }

    function _updateLPSupply(address pair) internal {
        pools[pair].lpStakingInfo.lpSupply = IBrewlabsPair(pair).totalSupply();
    }

    function _updateLPRewardsTable(address pair) internal {
        LPStakingInfo storage lpStakingInfo = pools[pair].lpStakingInfo;
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;

        uint balance0 = pools[pair].balanceOfLpProvider[token0];
        uint balance1 = pools[pair].balanceOfLpProvider[token1];

        uint leftOver0 = balance0 - lpStakingInfo.accRewards0;
        uint leftOver1 = balance1 - lpStakingInfo.accRewards1;

        for (uint i; i < lpStakingInfo.lpStakersArray.length; i++) {
            address lpStaker = lpStakingInfo.lpStakersArray[i];
            uint amount0Plus = leftOver0
                .mul(lpStakingInfo.lpStaked[lpStaker])
                .div(lpStakingInfo.lpSupply);
            uint amount1Plus = leftOver1
                .mul(lpStakingInfo.lpStaked[lpStaker])
                .div(lpStakingInfo.lpSupply);

            pools[pair].lpStakingInfo.rewardsTable0[lpStaker] += amount0Plus;
            pools[pair].lpStakingInfo.rewardsTable1[lpStaker] += amount1Plus;

            pools[pair].lpStakingInfo.accRewards0 += amount0Plus;
            pools[pair].lpStakingInfo.accRewards1 += amount1Plus;
        }
    }

    function _claimLPFee(address pair, address to) internal {
        _updateStakedLP(pair, to);
        (uint amount0, uint amount1) = pendingLPRewards(pair, to);
        if (amount0 > 0 || amount1 > 0) {
            _updateLPRewardsTable(pair);
            __claimLPFee(pair, to);
        }
    }

    function __claimLPFee(address pair, address to) internal {
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        uint claimAmount0 = pools[pair].lpStakingInfo.rewardsTable0[to];
        uint claimAmount1 = pools[pair].lpStakingInfo.rewardsTable1[to];
        pools[pair].lpStakingInfo.accRewards0 -= claimAmount0;
        pools[pair].lpStakingInfo.accRewards1 -= claimAmount1;
        pools[pair].lpStakingInfo.rewardsTable0[to] = 0;
        pools[pair].lpStakingInfo.rewardsTable1[to] = 0;

        if (claimAmount0 > 0) {
            pools[pair].balanceOfLpProvider[token0] -= claimAmount0;
            pools[pair].totalBalance[token0] -= claimAmount0;
            IERC20(token0).transfer(to, claimAmount0);
        }
        if (claimAmount1 > 0) {
            pools[pair].balanceOfLpProvider[token1] -= claimAmount1;
            pools[pair].totalBalance[token1] -= claimAmount1;
            IERC20(token1).transfer(to, claimAmount1);
        }
    }

    function _claimReferralFee(address pair) internal {
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        address referrer = pools[pair].referrer;
        uint rewards0 = pools[pair].balanceOfReferral[token0];
        uint rewards1 = pools[pair].balanceOfReferral[token1];

        if (rewards0 > 0) {
            pools[pair].balanceOfReferral[token0] = 0;
            pools[pair].totalBalance[token0] -= rewards0;
            IERC20(token0).transfer(referrer, rewards0);
        }
        if (rewards1 > 0) {
            pools[pair].balanceOfReferral[token1] = 0;
            pools[pair].totalBalance[token1] -= rewards1;
            IERC20(token1).transfer(referrer, rewards1);
        }
    }

    function _claimTokenHolderFee(address pair, address to) internal {
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        uint256 balance0 = IERC20(token0).balanceOf(to);
        uint256 balance1 = IERC20(token1).balanceOf(to);
        uint256 totalSupply0 = IERC20(token0).totalSupply();
        uint256 totalSupply1 = IERC20(token1).totalSupply();
        uint256 rewards0 = pools[pair].balanceOfTokenHolder[token0];
        uint256 rewards1 = pools[pair].balanceOfTokenHolder[token1];

        if (balance0 > 0 && rewards0 > 0) {
            uint256 amount = rewards0.mul(balance0).div(
                totalSupply0.sub(rewards0)
            );
            pools[pair].balanceOfTokenHolder[token0] -= amount;
            pools[pair].totalBalance[token0] -= amount;
            IERC20(token0).transfer(to, amount);
        }
        if (balance1 > 0 && rewards1 > 0) {
            uint256 amount = rewards1.mul(balance1).div(
                totalSupply1.sub(rewards1)
            );
            pools[pair].balanceOfTokenHolder[token1] -= amount;
            pools[pair].totalBalance[token1] -= amount;
            IERC20(token1).transfer(to, amount);
        }
    }

    function _claimTokenOwnerFee(
        address pair,
        address to,
        address token
    ) internal {
        require(
            token != address(0),
            "BrewlabsFeeManager: INVALID TOKEN ADDRESS"
        );
        uint rewards = pools[pair].balanceOfTokenOwner[token];
        if (rewards > 0) {
            pools[pair].balanceOfTokenOwner[token] = 0;
            pools[pair].totalBalance[token] -= rewards;
            IERC20(token).transfer(to, rewards);
        }
    }

    function _claimBrewlabsFee(address pair) internal {
        address token0 = pools[pair].token0;
        address token1 = pools[pair].token1;
        uint rewards0 = pools[pair].balanceOfBrewlabs[token0];
        uint rewards1 = pools[pair].balanceOfBrewlabs[token1];

        if (rewards0 > 0) {
            pools[pair].balanceOfBrewlabs[token0] = 0;
            pools[pair].totalBalance[token0] -= rewards0;
            IERC20(token0).transfer(brewlabsFeeTo, rewards0);
        }
        if (rewards1 > 0) {
            pools[pair].balanceOfBrewlabs[token1] = 0;
            pools[pair].totalBalance[token1] -= rewards1;
            IERC20(token1).transfer(brewlabsFeeTo, rewards1);
        }
    }
}