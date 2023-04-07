// SPDX-License-Identifier: MIT
// GoldQuality

pragma solidity ^0.8.19;

import "IERC20.sol";
import "IBaseStaking.sol";
import "Ownable.sol";

contract BaseStaking is IBaseStaking, Ownable {
    IERC20 public token;
    uint256 public startDate;
    bool public isRun;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake[]) public stakes;
    uint256[] public firstDatePercents;
    uint256[] public firstDateYears;
    uint256[] public bonusPercents;
    uint256[] public bonusDays;

    uint256 constant private SECONDS_IN_DAY = 86400;
    uint256 constant private SECONDS_IN_YEAR = 31536000;

    event Staked(address indexed user, uint256 amount);
    event UnStaked(address indexed user, uint256 amount, uint256 rewardAmount);
    event Stop(address user);

    constructor(address _token, uint256 _startDate)
    {
        require(_startDate <= block.timestamp, "Amount must not be zero");

        token = IERC20(_token);
        startDate = _startDate;
        isRun = true;

        firstDateYears = [0, 1, 2];
        firstDatePercents = [37, 27, 17];

        bonusDays = [0, 90, 120, 150, 180, 240, 300, 360, 450, 540, 630, 720, 900];
        bonusPercents = [0, 1, 2, 3, 5, 7, 8, 10, 12, 13, 14, 15, 16];
    }

    function getStakeCount(address _user)
    external view
    returns (uint256)
    {
        return stakes[_user].length;
    }

    function getStakeInfo(address _user)
    public view
    returns (
        uint256 totalAmount,
        uint256 rewardAmount
    )
    {
        (totalAmount, rewardAmount) = (0, 0);

        for (uint256 i = 0; i < stakes[_user].length; i++) {
            totalAmount += stakes[_user][i].amount;

            uint256 yearPassed = (block.timestamp - startDate) / SECONDS_IN_YEAR;
            uint256 daysPassed = (block.timestamp - stakes[_user][i].timestamp) / SECONDS_IN_DAY;

            rewardAmount += stakes[_user][i].amount * (
                firstDatePercents[_getRightIndex(firstDateYears, yearPassed)] +
                bonusPercents[_getRightIndex(bonusDays, daysPassed)]
            ) * daysPassed / (100 * 365);
        }
    }

    function stop()
    external onlyOwner
    {
        require(isRun, "Already stopped");
        isRun = false;

        emit Stop(_msgSender());
    }

    function stake(uint256 _amount)
    external
    {
        require(isRun, "Staking is closed");
        require(_amount != 0, "Amount must not be zero");
        require(token.balanceOf(_msgSender()) >= _amount, "Not enough tokens");
        require(token.allowance(_msgSender(), address(this)) >= _amount, "Token allowance is low");

        require(token.transferFrom(_msgSender(), address(this), _amount), "Token transfer failed");

        stakes[_msgSender()].push(Stake(_amount, block.timestamp));

        emit Staked(_msgSender(), _amount);
    }

    function unStake()
    external
    {
        require(stakes[_msgSender()].length != 0, "No stakes");

        (uint256 totalAmount, uint256 rewardAmount) = getStakeInfo(_msgSender());

        require(totalAmount + rewardAmount <= token.balanceOf(address(this)) , "Insufficient staking balance");

        delete stakes[_msgSender()];
        token.transfer(_msgSender(), totalAmount + rewardAmount);

        emit UnStaked(_msgSender(), totalAmount, rewardAmount);
    }

    function _getRightIndex(
        uint256[] memory array,
        uint256 value
    )
    internal view
    returns (uint256)
    {
        uint256 index = 1;

        while (index < array.length) {
            if (value < array[index]) {
                break;
            } else {
                index++;
            }
        }

        return index - 1;
    }
}