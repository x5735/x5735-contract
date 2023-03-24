// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ltyStaking is Ownable, ReentrancyGuard, Pausable {
    address private reserve; // the reserve address
    IERC20 private immutable lty; // the lty token

    address[] public userStaked; // the user who staked
    mapping(address => uint256) public staked; // how much the user staked
    mapping(address => uint256) public timeStaked; // when the user staked

    uint256 public totalStaked; // the total staked

    uint256 public APY; // APY based on the total staked with 3 decimals (ex: 100 = 0.1 = 10%)

    constructor(address _reserve, address _lty, uint256 _APY) {
        require(_reserve != address(0), "The reserve address can't be 0");
        require(_lty != address(0), "The lty address can't be 0");
        reserve = _reserve;
        lty = IERC20(_lty);
        APY = _APY;
    }

    /**
     * @dev pause the claim / stake / unstake functions
     **/
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause the claim / stake / unstake functions
     **/
    function unpause() external onlyOwner {
        _unpause();
    }

    /*
     * @dev function to set the reserve address
     * @param _reserve the reserve address
     */
    function setReserve(address _reserve) external onlyOwner {
        reserve = _reserve;
    }

    /*
     * @dev function to set the APY with 3 decimals (ex: 100 = 0.1 = 10%) and claim the reward for all users
     * @param _APY the APY
     */
    function setAPY(uint256 _APY) external onlyOwner {
        uint256 actualDate = block.timestamp;

        for (uint i = 0; i < userStaked.length; i++) {
            address user = userStaked[i];

            if (timeStaked[user] < actualDate) {
                uint256 reward = rewardByUser(user);

                lty.transferFrom(reserve, address(this), reward);

                timeStaked[user] = actualDate;
                staked[user] += reward;
                totalStaked += reward;
            }
        }
        APY = _APY;
    }

    /*
     * @dev function to calculate the reward
     * @param _user the user address
     * @return the reward of the user in LTY
     */
    function rewardByUser(address _user) public view returns (uint256) {
        if (staked[_user] == 0) return 0;

        uint256 _amountStaked = staked[_user];
        uint256 _timeStaked = timeStaked[_user];

        uint256 timeDiff = block.timestamp - _timeStaked;
        uint256 rewardInterval = 365 days;

        return (((_amountStaked * APY) *
            ((timeDiff * 10 ** 18) / rewardInterval)) / 10 ** 21); // 10 ** 18 for the decimals to not be at 0, 10 ** 3 for the APY, finally : 21 = 18 + 3
    }

    /*
     * @dev function to claim the reward of the user
     */
    function claim() external whenNotPaused nonReentrant {
        require(staked[msg.sender] > 0, "You don't have any staked LTY");
        require(
            timeStaked[msg.sender] < block.timestamp,
            "You can't claim yet"
        );

        uint256 reward = rewardByUser(msg.sender);
        timeStaked[msg.sender] = block.timestamp;

        lty.transferFrom(reserve, msg.sender, reward);
    }

    /*
     * @dev function to stake the tokens and get the reward if there is one
     * @param _amount the amount of tokens to stake
     */
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "You must stake more than 0");
        require(
            lty.balanceOf(msg.sender) >= _amount,
            "You don't have enough LTY"
        );
        require(
            lty.allowance(msg.sender, address(this)) >= _amount,
            "You must approve the contract to spend your LTY"
        );

        uint256 reward = rewardByUser(msg.sender);

        lty.transferFrom(msg.sender, address(this), _amount);

        if (staked[msg.sender] == 0) {
            userStaked.push(msg.sender);
        }

        staked[msg.sender] += _amount + reward;
        timeStaked[msg.sender] = block.timestamp;
        totalStaked += _amount + reward;

        if (reward > 0) {
            lty.transferFrom(reserve, address(this), reward);
        }
    }

    /*
     * @dev function to unstake the tokens and get the reward
     */
    function unstake(uint256 _amount) external whenNotPaused nonReentrant {
        require(
            staked[msg.sender] >= _amount,
            "You don't have enough staked LTY"
        );
        require(
            timeStaked[msg.sender] < block.timestamp,
            "You can't claim yet"
        );

        uint256 reward = rewardByUser(msg.sender);

        timeStaked[msg.sender] = block.timestamp;
        staked[msg.sender] -= _amount;
        totalStaked -= _amount;

        if (staked[msg.sender] == 0) {
            for (uint i = 0; i < userStaked.length; i++) {
                if (userStaked[i] == msg.sender) {
                    userStaked[i] = userStaked[userStaked.length - 1];
                    userStaked.pop();
                    break;
                }
            }
        }

        lty.transfer(msg.sender, _amount);
        lty.transferFrom(reserve, msg.sender, reward);
    }
}