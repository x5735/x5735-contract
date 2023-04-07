// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits & Kevin
// Burns CZUSD, tracks locked liquidity, trades to BNB and sends to Kevin for running green miners
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/utils/Checkpoints.sol";
import "./czodiac/CZUSD.sol";
import "./AutoRewardPool.sol";
import "./libs/AmmLibrary.sol";
import "./interfaces/IAmmFactory.sol";
import "./interfaces/IAmmPair.sol";
import "./interfaces/IAmmRouter02.sol";

contract BRAG is
    ERC20PresetFixedSupply,
    AccessControlEnumerable,
    KeeperCompatibleInterface
{
    using SafeERC20 for IERC20;
    using Address for address payable;
    using Checkpoints for Checkpoints.History;
    bytes32 public constant MANAGER = keccak256("MANAGER");
    AutoRewardPool public rewardsDistributor;

    Checkpoints.History totalSupplyHistory;

    IERC20 public constant BTCB =
        IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    uint256 public burnBPS = 700;
    uint256 public maxBurnBPS = 3000;
    mapping(address => bool) public isExempt;

    IAmmPair public ammCzusdPair;
    IAmmRouter02 public ammRouter;
    CZUsd public czusd;

    uint256 public baseCzusdLocked;
    uint256 public totalCzusdSpent;
    uint256 public lockedCzusdTriggerLevel = 100 ether;

    bool public tradingOpen;

    address public projectDistributor;
    uint256 public projectBasis = 400;

    constructor(
        CZUsd _czusd,
        IAmmRouter02 _ammRouter,
        IAmmFactory _factory,
        address _rewardsDistributor,
        uint256 _baseCzusdLocked,
        uint256 _totalSupply,
        address _projectDistributor
    )
        ERC20PresetFixedSupply(
            "Raging Bull Network",
            "BRAG",
            _totalSupply,
            msg.sender
        )
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        _grantRole(MANAGER, _rewardsDistributor);
        _grantRole(MANAGER, _projectDistributor);

        ADMIN_setCzusd(_czusd);
        ADMIN_setAmmRouter(_ammRouter);
        ADMIN_setBaseCzusdLocked(_baseCzusdLocked);
        MANAGER_setProjectDistributor(_projectDistributor);
        MANAGER_setRewardsDistributor(_rewardsDistributor);

        MANAGER_setIsExempt(msg.sender, true);
        MANAGER_setIsExempt(_rewardsDistributor, true);

        ammCzusdPair = IAmmPair(
            _factory.createPair(address(this), address(czusd))
        );
        totalSupplyHistory.push(totalSupply());
    }

    function lockedCzusd() public view returns (uint256 lockedCzusd_) {
        bool czusdIsToken0 = ammCzusdPair.token0() == address(czusd);
        (uint112 reserve0, uint112 reserve1, ) = ammCzusdPair.getReserves();
        uint256 lockedLP = ammCzusdPair.balanceOf(address(this));
        uint256 totalLP = ammCzusdPair.totalSupply();

        uint256 lockedLpCzusdBal = ((czusdIsToken0 ? reserve0 : reserve1) *
            lockedLP) / totalLP;
        uint256 lockedLpBragBal = ((czusdIsToken0 ? reserve1 : reserve0) *
            lockedLP) / totalLP;

        if (lockedLpBragBal == totalSupply()) {
            lockedCzusd_ = lockedLpCzusdBal;
        } else {
            lockedCzusd_ =
                lockedLpCzusdBal -
                (
                    AmmLibrary.getAmountOut(
                        totalSupply() - lockedLpBragBal,
                        lockedLpBragBal,
                        lockedLpCzusdBal
                    )
                );
        }
    }

    function availableWadToSend() public view returns (uint256) {
        return lockedCzusd() - baseCzusdLocked - totalCzusdSpent;
    }

    function isOverTriggerLevel() public view returns (bool) {
        return lockedCzusdTriggerLevel <= availableWadToSend();
    }

    function getTotalSupplyAtBlock(uint256 _blockNumber)
        external
        view
        returns (uint256 wad_)
    {
        return totalSupplyHistory.getAtBlock(_blockNumber);
    }

    function checkUpkeep(bytes calldata)
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory)
    {
        upkeepNeeded =
            isOverTriggerLevel() &&
            (availableWadToSend() < czusd.balanceOf(address(this)));
    }

    function performUpkeep(bytes calldata) external override {
        uint256 wadToSend = availableWadToSend();
        totalCzusdSpent += wadToSend;
        czusd.approve(address(ammRouter), wadToSend);
        address[] memory path = new address[](4);
        path[0] = address(czusd);
        path[1] = ammRouter.WETH(); //BNB
        path[2] = address(BTCB); //BTCB
        ammRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            czusd.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
        BTCB.transfer(
            projectDistributor,
            (BTCB.balanceOf(address(this)) * projectBasis) / burnBPS
        );
        BTCB.transfer(
            address(rewardsDistributor),
            BTCB.balanceOf(address(this))
        );
    }

    function _burn(address _sender, uint256 _burnAmount) internal override {
        super._burn(_sender, _burnAmount);
        totalSupplyHistory.push(totalSupply());
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        //Handle burn
        if (isExempt[sender] || isExempt[recipient]) {
            super._transfer(sender, recipient, amount);
            rewardsDistributor.deposit(recipient, amount);
            rewardsDistributor.withdraw(sender, amount);
        } else {
            require(tradingOpen, "BRAG: Not open");
            uint256 burnAmount = (amount * burnBPS) / 10000;
            if (burnAmount > 0) _burn(sender, burnAmount);
            uint256 postBurnAmount = amount - burnAmount;
            super._transfer(sender, recipient, postBurnAmount);
            rewardsDistributor.deposit(recipient, postBurnAmount);
            rewardsDistributor.withdraw(sender, amount);
        }
    }

    function MANAGER_setIsExempt(address _for, bool _to)
        public
        onlyRole(MANAGER)
    {
        isExempt[_for] = _to;
    }

    function MANAGER_setBps(uint256 _toBps) public onlyRole(MANAGER) {
        require(_toBps <= maxBurnBPS, "BRAG: Burn too high");
        burnBPS = _toBps;
    }

    function MANAGER_setRewardsDistributor(address _to)
        public
        onlyRole(MANAGER)
    {
        rewardsDistributor = AutoRewardPool(_to);
    }

    function MANAGER_setProjectDistributor(address _to)
        public
        onlyRole(MANAGER)
    {
        projectDistributor = _to;
    }

    function ADMIN_openTrading() external onlyRole(DEFAULT_ADMIN_ROLE) {
        tradingOpen = true;
    }

    function ADMIN_recoverERC20(address tokenAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC20(tokenAddress).transfer(
            _msgSender(),
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }

    function ADMIN_withdraw(address payable _to)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _to.sendValue(address(this).balance);
    }

    function ADMIN_setBaseCzusdLocked(uint256 _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseCzusdLocked = _to;
    }

    function ADMIN_setProjectBasis(uint256 _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        projectBasis = _to;
    }

    function ADMIN_setLockedCzusdTriggerLevel(uint256 _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        lockedCzusdTriggerLevel = _to;
    }

    function ADMIN_setAmmRouter(IAmmRouter02 _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ammRouter = _to;
    }

    function ADMIN_setCzusd(CZUsd _to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        czusd = _to;
    }

    function ADMIN_setMaxBurnBps(uint256 _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        maxBurnBPS = _to;
    }
}