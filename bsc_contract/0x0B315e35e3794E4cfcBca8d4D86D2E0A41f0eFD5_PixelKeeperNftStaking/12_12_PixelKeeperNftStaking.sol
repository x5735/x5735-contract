// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @author Brewlabs
 * This contract has been developed by brewlabs.info
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IPixelKeeperNft {
    function rarityOfItem(uint256 tokenId) external view returns (uint256);
}

contract PixelKeeperNftStaking is Ownable, IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    uint256 private constant BLOCKS_PER_DAY = 28800;
    uint256 private PRECISION_FACTOR;

    // Whether it is initialized
    bool public isInitialized;
    uint256 public duration = 365; // 365 days

    // The block number when staking starts.
    uint256 public startBlock;
    // The block number when staking ends.
    uint256 public bonusEndBlock;
    // tokens created per block.
    uint256 public rewardPerBlock;
    // The block number of the last pool update
    uint256 public lastRewardBlock;

    uint256[3] public totalRewardsOfRarity = [87.5 ether, 37.5 ether, 20 ether];
    uint256[3] private rewardsPerBlockOfRarity;

    address public treasury = 0x5Ac58191F3BBDF6D037C6C6201aDC9F99c93C53A;
    uint256 public performanceFee = 0.0035 ether;

    // The staked token
    IERC721 public stakingNft;
    // The earned token
    IERC20 public earnedToken;
    // Accrued token per share
    uint256 public accTokenPerShare;
    uint256 public oneTimeLimit = 40;

    uint256 public totalStaked;
    uint256[3] private totalStakedOfRarity;
    uint256 public paidRewards;
    uint256 private shouldTotalPaid;

    struct UserInfo {
        uint256 amount; // number of staked NFTs
        uint256[3] amounts; // number of NFTs of specific rarity
        uint256[] tokenIds; // staked tokenIds
        uint256 lastRewardBlock; // Reward debt
    }
    // Info of each user that stakes tokenIds

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256[] tokenIds);
    event Withdraw(address indexed user, uint256[] tokenIds);
    event Claim(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256[] tokenIds);
    event AdminTokenRecovered(address tokenRecovered, uint256 amount);

    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewards(uint256[3] rewardsOfRarity);
    event RewardsStop(uint256 blockNumber);
    event EndBlockUpdated(uint256 blockNumber);

    event ServiceInfoUpadted(address _addr, uint256 _fee);
    event SetOneTimeLimit(uint256 limit);
    event DurationUpdated(uint256 _duration);

    constructor() {}

    /**
     * @notice Initialize the contract
     * @param _stakingNft: nft address to stake
     * @param _earnedToken: earned token address
     */
    function initialize(IERC721 _stakingNft, IERC20 _earnedToken) external onlyOwner {
        require(!isInitialized, "Already initialized");

        // Make this contract initialized
        isInitialized = true;

        stakingNft = _stakingNft;
        earnedToken = _earnedToken;

        for (uint256 i = 0; i < 3; i++) {
            rewardsPerBlockOfRarity[i] = totalRewardsOfRarity[i] / duration / BLOCKS_PER_DAY;
        }

        uint256 decimalsRewardToken = uint256(IERC20Metadata(address(earnedToken)).decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");
        PRECISION_FACTOR = uint256(10 ** (40 - decimalsRewardToken));
    }

    /**
     * @notice Deposit NFTs and collect reward tokens (if any)
     * @param _tokenIds: tokenIds to stake
     */
    function deposit(uint256[] memory _tokenIds) external payable nonReentrant {
        require(startBlock > 0 && startBlock < block.number, "Staking hasn't started yet");
        require(_tokenIds.length > 0, "must add at least one tokenId");
        require(_tokenIds.length <= oneTimeLimit, "cannot exceed one-time limit");

        _transferPerformanceFee();
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            uint256 pending = pendingReward(msg.sender);
            if (pending > 0) {
                require(availableRewardTokens() >= pending, "Insufficient reward tokens");
                earnedToken.safeTransfer(address(msg.sender), pending);
                paidRewards += pending;
                emit Claim(msg.sender, pending);
            }
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            stakingNft.safeTransferFrom(msg.sender, address(this), tokenId);
            user.tokenIds.push(tokenId);

            uint256 rarity = IPixelKeeperNft(address(stakingNft)).rarityOfItem(tokenId);
            user.amounts[rarity]++;
            totalStakedOfRarity[rarity]++;
        }
        user.amount = user.amount + _tokenIds.length;
        user.lastRewardBlock = block.number;

        totalStaked = totalStaked + _tokenIds.length;
        emit Deposit(msg.sender, _tokenIds);
    }

    /**
     * @notice Withdraw staked tokenIds and collect reward tokens
     * @param _amount: number of tokenIds to unstake
     */
    function withdraw(uint256 _amount) external payable nonReentrant {
        require(_amount > 0, "Amount should be greator than 0");
        require(_amount <= oneTimeLimit, "cannot exceed one-time limit");

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Amount to withdraw too high");

        _transferPerformanceFee();
        _updatePool();

        if (user.amount > 0) {
            uint256 pending = pendingReward(msg.sender);
            if (pending > 0) {
                require(availableRewardTokens() >= pending, "Insufficient reward tokens");
                earnedToken.safeTransfer(address(msg.sender), pending);
                paidRewards += pending;
                emit Claim(msg.sender, pending);
            }
        }

        uint256[] memory _tokenIds = new uint256[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = user.tokenIds[user.tokenIds.length - 1];
            user.tokenIds.pop();

            _tokenIds[i] = tokenId;
            stakingNft.safeTransferFrom(address(this), msg.sender, tokenId);

            uint256 rarity = IPixelKeeperNft(address(stakingNft)).rarityOfItem(tokenId);
            user.amounts[rarity]--;
            totalStakedOfRarity[rarity]--;
        }
        user.amount = user.amount - _amount;
        user.lastRewardBlock = block.number;

        totalStaked = totalStaked - _amount;
        emit Withdraw(msg.sender, _tokenIds);
    }

    function claimReward() external payable nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _transferPerformanceFee();
        _updatePool();

        if (user.amount == 0) return;

        uint256 pending = pendingReward(msg.sender);
        if (pending > 0) {
            require(availableRewardTokens() >= pending, "Insufficient reward tokens");
            earnedToken.safeTransfer(address(msg.sender), pending);
            paidRewards += pending;
        }

        user.lastRewardBlock = block.number;
        emit Claim(msg.sender, pending);
    }

    /**
     * @notice Withdraw staked NFTs without caring about rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _amount = user.amount;
        if (_amount > oneTimeLimit) _amount = oneTimeLimit;

        uint256[] memory _tokenIds = new uint256[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = user.tokenIds[user.tokenIds.length - 1];
            user.tokenIds.pop();

            _tokenIds[i] = tokenId;
            stakingNft.safeTransferFrom(address(this), msg.sender, tokenId);

            uint256 rarity = IPixelKeeperNft(address(stakingNft)).rarityOfItem(tokenId);
            user.amounts[rarity]--;
            totalStakedOfRarity[rarity]--;
        }
        user.amount = user.amount - _amount;
        user.lastRewardBlock = block.number;
        totalStaked = totalStaked - _amount;

        emit EmergencyWithdraw(msg.sender, _tokenIds);
    }

    function stakedInfo(address _user) external view returns (uint256, uint256[] memory, uint256[3] memory) {
        return (userInfo[_user].amount, userInfo[_user].tokenIds, userInfo[_user].amounts);
    }

    /**
     * @notice Available amount of reward token
     */
    function availableRewardTokens() public view returns (uint256) {
        return earnedToken.balanceOf(address(this));
    }

    /**
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (user.amount == 0) return 0;

        uint256 multiplier = _getMultiplier(user.lastRewardBlock, block.number);
        uint256 pending;
        for (uint256 i = 0; i < 3; i++) {
            pending += multiplier * user.amounts[i] * rewardsPerBlockOfRarity[i];
        }

        return pending;
    }

    /**
     * @notice Withdraw reward token
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        require(block.number > bonusEndBlock, "Pool is running");
        require(availableRewardTokens() >= _amount, "Insufficient reward tokens");

        if (_amount == 0) _amount = availableRewardTokens();
        earnedToken.safeTransfer(address(msg.sender), _amount);
    }

    function startReward() external onlyOwner {
        require(startBlock == 0, "Pool was already started");

        startBlock = block.number + 100;
        bonusEndBlock = startBlock + duration * BLOCKS_PER_DAY;
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(startBlock, bonusEndBlock);
    }

    function stopReward() external onlyOwner {
        _updatePool();

        uint256 remainRewards = availableRewardTokens() + paidRewards;
        if (remainRewards > shouldTotalPaid) {
            remainRewards = remainRewards - shouldTotalPaid;
            earnedToken.transfer(msg.sender, remainRewards);
        }
        bonusEndBlock = block.number;
        emit RewardsStop(bonusEndBlock);
    }

    function updateEndBlock(uint256 _endBlock) external onlyOwner {
        require(startBlock > 0, "Pool is not started");
        require(bonusEndBlock > block.number, "Pool was already finished");
        require(_endBlock > block.number && _endBlock > startBlock, "Invalid end block");

        bonusEndBlock = _endBlock;
        emit EndBlockUpdated(_endBlock);
    }

    /**
     * @notice Update rewards of each rarity
     * @dev Only callable by owner.
     * @param _rewards: the reward per block
     */
    function setTotalRewardsForRarities(uint256[3] memory _rewards) external onlyOwner {
        _updatePool();

        totalRewardsOfRarity = _rewards;
        for (uint256 i = 0; i < 3; i++) {
            rewardsPerBlockOfRarity[i] = totalRewardsOfRarity[i] / duration / BLOCKS_PER_DAY;
        }
        emit NewRewards(_rewards);
    }

    function setOneTimeLimit(uint256 _limit) external onlyOwner {
        require(_limit < 200, "too many");
        oneTimeLimit = _limit;
        emit SetOneTimeLimit(_limit);
    }

    function setServiceInfo(address _treasury, uint256 _fee) external {
        require(msg.sender == treasury, "setServiceInfo: FORBIDDEN");
        require(_treasury != address(0x0), "Invalid address");

        treasury = _treasury;
        performanceFee = _fee;
        emit ServiceInfoUpadted(_treasury, _fee);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _token: the address of the token to withdraw
     * @dev This function is only callable by admin.
     */
    function rescueTokens(address _token) external onlyOwner {
        require(_token != address(earnedToken), "Cannot be reward token");

        uint256 amount = address(this).balance;
        if (_token == address(0x0)) {
            payable(msg.sender).transfer(amount);
        } else {
            amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(address(msg.sender), amount);
        }

        emit AdminTokenRecovered(_token, amount);
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock || lastRewardBlock == 0) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 _reward;
        for (uint256 i = 0; i < 3; i++) {
            _reward += multiplier * totalStakedOfRarity[i] * rewardsPerBlockOfRarity[i];
        }
        shouldTotalPaid += _reward;
        lastRewardBlock = block.number;
    }

    /**
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to - _from;
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock - _from;
        }
    }

    function _transferPerformanceFee() internal {
        require(msg.value >= performanceFee, "should pay small gas to compound or harvest");

        payable(treasury).transfer(performanceFee);
        if (msg.value > performanceFee) {
            payable(msg.sender).transfer(msg.value - performanceFee);
        }
    }

    /**
     * onERC721Received(address operator, address from, uint256 tokenId, bytes data) ¡ú bytes4
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        require(msg.sender == address(stakingNft), "not enabled NFT");
        return _ERC721_RECEIVED;
    }

    receive() external payable {}
}