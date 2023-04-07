//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";

abstract contract IERC20Burn is ReentrancyGuard, Ownable {
    struct Plan {
        uint256 overallBurned;
        uint256 overallTreasureCoinsEarned;
        uint256 burnedCount;
        uint256 treasureCoinRewardsPerTokenBurned;
        bool conclude;
    }

    struct Burn {
        uint256 amount;
        uint256 treasureCoinEarned;
        uint256 burnAt;
    }

    mapping(uint256 => mapping(address => Burn[])) public burns;

    address[] burnAddresses;

    address public burningToken;
    mapping(uint256 => Plan) public plans;
    address burnAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 treasureCoinDecimal = 3;

    constructor(address _burningToken) {
        burningToken = _burningToken;
    }

    function burn(uint256 _burnId, uint256 _amount) public virtual;

    function getTreasureRewards(uint256 _burnId, address account)
        public
        view
        virtual
        returns (uint256);
    
    function getBurned(uint256 _burnId, address account)
        public
        view
        virtual
        returns (uint256);

    function getTotalBurned(uint256 _burnId)
        public
        view
        virtual
        returns (uint256);

    function getTotalTreasureRewards(uint256 _burnId)
        public
        view
        virtual
        returns (uint256);
}

contract ShinuBurn is IERC20Burn {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public planLimit = 1;
    uint256 minAPR = 1 * (10**(treasureCoinDecimal)).div(1000);

    constructor(address _burningToken) IERC20Burn(_burningToken) {
        plans[0].treasureCoinRewardsPerTokenBurned =
            1 *
            (10**(treasureCoinDecimal)).div(10);
    }

    function burn(uint256 _burnId, uint256 _amount)
        public
        override
        nonReentrant
    {
        require(_amount > 0, "Burn Amount cannot be zero");
        require(
            IERC20(burningToken).balanceOf(msg.sender) >= _amount,
            "Balance is not enough"
        );
        require(_burnId < planLimit, "Burn Plan is unavailable");

        Plan storage plan = plans[_burnId];
        require(!plan.conclude, "Burning in this pool is concluded");

        IERC20(burningToken).transferFrom(msg.sender, burnAddress, _amount);

        uint256 burnlength = burns[_burnId][msg.sender].length;

        if (burnlength == 0) {
            plan.burnedCount += 1;
        }

        if(!addressExists(burnAddresses, msg.sender)) {
            burnAddresses.push(msg.sender);
        }

        burns[_burnId][msg.sender].push();

        Burn storage _burn = burns[_burnId][msg.sender][burnlength];
        _burn.amount = _amount;
        _burn.treasureCoinEarned = _amount.mul(
            plan.treasureCoinRewardsPerTokenBurned
        );
        _burn.burnAt = block.timestamp;

        plan.overallBurned = plan.overallBurned.add(_burn.amount);

        plan.overallTreasureCoinsEarned = plan.overallTreasureCoinsEarned.add(
            _burn.treasureCoinEarned
        );
    }

    function getTreasureRewards(uint256 _burnId, address account)
        public
        view
        override
        returns (uint256)
    {
        uint256 _earned = 0;
        for (uint256 i = 0; i < burns[_burnId][account].length; i++) {
            Burn storage _burn = burns[_burnId][account][i];
            _earned = _earned.add(_burn.treasureCoinEarned);
        }

        return _earned;
    }

    function getBurned(uint256 _burnId, address account)
        public
        view
        override
        returns (uint256)
    {
        uint256 _burned = 0;
        for (uint256 i = 0; i < burns[_burnId][account].length; i++) {
            Burn storage _burn = burns[_burnId][account][i];
            _burned = _burned.add(_burn.amount);
        }

        return _burned;
    }

    function getTotalBurned(uint256 _burnId)
        public
        view
        override
        returns (uint256)
    {
        Plan storage plan = plans[_burnId];
        return plan.overallBurned;
    }

    function getTotalTreasureRewards(uint256 _burnId)
        public
        view
        override
        returns (uint256)
    {
        Plan storage plan = plans[_burnId];
        return plan.overallTreasureCoinsEarned;
    }

    function addressExists(address[] memory array, address search) public pure returns (bool){
      
      for (uint256 i; i < array.length; i++){
          if (array[i] == search)
            return true;
      }

      return false;
    }

    function setTreasureCoinRewardsPerTokenBurned(
        uint256 _burnId,
        uint256 _value
    ) external onlyOwner {
        require(_value >= minAPR);
        plans[_burnId].treasureCoinRewardsPerTokenBurned = _value;
    }

    function setBurningConclude(uint256 _burnId, bool _conclude)
        external
        onlyOwner
    {
        plans[_burnId].conclude = _conclude;
    }
}
