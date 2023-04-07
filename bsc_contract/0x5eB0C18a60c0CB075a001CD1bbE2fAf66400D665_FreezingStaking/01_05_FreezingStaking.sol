// SPDX-License-Identifier: MIT
// GoldQuality

pragma solidity ^0.8.19;

import "IERC20.sol";
import "IFreezingStaking.sol";
import "Ownable.sol";

contract FreezingStaking is IFreezingStaking, Ownable {
    IERC20 public token;
    bool public isRun;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 period;
    }

    mapping(address => Stake[]) public stakes;
    mapping(uint256 => uint256) public period2percent;

    uint256 constant private SECONDS_IN_DAY = 86400;

    event Staked(address indexed user, uint256 period, uint256 amount);
    event UnStaked(address indexed user, uint256 amount, uint256 rewardAmount);
    event Stop(address user);

    constructor(address _token)
    {
        token = IERC20(_token);
        isRun = true;

        period2percent[180] = 40;
        period2percent[270] = 43;
        period2percent[360] = 45;
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
        uint256 availableAmount,
        uint256 rewardAmount,
        bool[] memory available
    )
    {
        (totalAmount, availableAmount, rewardAmount, available) = (0, 0, 0, new bool[](stakes[_user].length));

        for (uint256 i = 0; i < stakes[_user].length; i++) {
            totalAmount += stakes[_user][i].amount;

            uint256 secondsPassed = block.timestamp - stakes[_user][i].timestamp;

            if (secondsPassed >= stakes[_user][i].period * SECONDS_IN_DAY) {
                available[i] = true;
                availableAmount += stakes[_user][i].amount;

                rewardAmount += stakes[_user][i].amount * period2percent[stakes[_user][i].period] * (secondsPassed / SECONDS_IN_DAY) / (100 * 365);
            }
        }
    }

    function stop()
    external onlyOwner
    {
        require(isRun, "Already stopped");
        isRun = false;

        emit Stop(_msgSender());
    }

    function stake(uint256 _amount, uint _period)
    external
    {
        require(isRun, "Staking is closed");
        require(_amount != 0, "Amount must not be zero");
        require(period2percent[_period] != 0, "Wrong period");
        require(token.balanceOf(_msgSender()) >= _amount, "Not enough tokens");
        require(token.allowance(_msgSender(), address(this)) >= _amount, "Token allowance is low");

        require(token.transferFrom(_msgSender(), address(this), _amount), "Token transfer failed");

        stakes[_msgSender()].push(Stake(_amount, block.timestamp, _period));

        emit Staked(_msgSender(), _period, _amount);
    }

    function unStake()
    external
    {
        require(stakes[_msgSender()].length != 0, "No stakes");

        (uint256 totalAmount, uint256 availableAmount, uint256 rewardAmount, bool[] memory available) = getStakeInfo(_msgSender());

        require(availableAmount != 0, "No stakes to withdraw");
        require(availableAmount + rewardAmount <= token.balanceOf(address(this)) , "Insufficient staking balance");

        for (uint256 i = 0; i < available.length; i++) {
            if (available[available.length - 1 - i]) {
                delete stakes[_msgSender()][available.length - 1 - i];
            }
        }

        token.transfer(_msgSender(), availableAmount + rewardAmount);

        emit UnStaked(_msgSender(), availableAmount, rewardAmount);
    }
}