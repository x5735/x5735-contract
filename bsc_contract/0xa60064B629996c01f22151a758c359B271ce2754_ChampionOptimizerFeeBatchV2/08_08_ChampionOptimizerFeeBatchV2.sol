// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract ChampionOptimizerFeeBatchV2 is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public wNative;
    address public coTreasury;
    address public strategist;
    address public chamStaker;

    // Fee constants
    uint constant public MAX_FEE = 1000;
    uint public coTreasuryFee;
    uint public strategistFee;
    uint public chamStakerFee;

    event NewCoTreasury(address oldValue, address newValue);
    event NewStrategist(address oldValue, address newValue);
    event NewChamStaker(address oldValue, address newValue);

    function initialize(
        address _wNative,
        address _coTreasury,  
        address _chamStaker,
        address _strategist,
        uint256 _chamStakerFee,
        uint256 _strategistFee  
    ) public initializer {
        __Ownable_init();
        wNative  = IERC20Upgradeable(_wNative);
        coTreasury = _coTreasury;
        chamStaker = _chamStaker;
        strategist = _strategist;

        chamStakerFee = _chamStakerFee;
        strategistFee = _strategistFee;
        coTreasuryFee = MAX_FEE - (chamStakerFee + strategistFee);
    }

    // Main function. Divides profits.
    function harvest(address _token) public {
        IERC20Upgradeable token = IERC20Upgradeable(_token);
        uint256 tokenBal = token.balanceOf(address(this));

        uint256 coTreasuryAmount = tokenBal * coTreasuryFee / MAX_FEE;
        token.safeTransfer(coTreasury, coTreasuryAmount);

        uint256 chamStakerAmount = tokenBal * chamStakerFee / MAX_FEE;
        token.safeTransfer(chamStaker, chamStakerAmount);

        uint256 strategistAmount = tokenBal * strategistFee / MAX_FEE;
        token.safeTransfer(strategist, strategistAmount);
    }

    function setCoTreasury(address _coTreasury) external onlyOwner {
        emit NewCoTreasury(coTreasury, _coTreasury);
        coTreasury = _coTreasury;
    }

    function setStrategist(address _strategist) external onlyOwner {
        emit NewStrategist(strategist, _strategist);
        strategist = _strategist;
    }

    function setChamStaker(address _chamStaker) external onlyOwner {
        emit NewChamStaker(chamStaker, _chamStaker);
        chamStaker = _chamStaker;
    }

    function setFees(
        uint256 _chamStakerFee,
        uint256 _strategistFee
    ) public onlyOwner {
        require(MAX_FEE >= (_chamStakerFee + _strategistFee), "CoFeeBatch: FEE_TOO_HIGH");
        chamStakerFee = _chamStakerFee;
        strategistFee = _strategistFee;
        coTreasuryFee = MAX_FEE - (chamStakerFee + strategistFee);
    }
    
    // Rescue locked funds sent by mistake
    function inCaseTokensGetStuck(address _token, address _recipient) external onlyOwner {
        require(_token != address(wNative), "CoFeeBatch: NATIVE_TOKEN");

        uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(_recipient, amount);
    }

    receive() external payable {}
}