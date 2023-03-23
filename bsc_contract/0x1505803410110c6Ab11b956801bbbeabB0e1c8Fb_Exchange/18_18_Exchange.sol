// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ILendingPool {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;
}

interface IFlashMall {
    function pointMint(uint256 amount) external;

    function pointBack(uint256 amount) external;

    function pointRate() external returns (uint16);
}

interface IMaiExchange {
    function lastPrice() external view returns (uint256);

    function withdraw(address token, uint256 amount) external;
}

interface IPancakeRouter {
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract Exchange is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant MAI = 0x35803e77c3163FEd8A942536C1c8e0d5bF90f906;
    address public constant MUSD = 0x22a2C54b15287472F4aDBe7587226E3c998CdD96;
    address public constant MCOIN = 0x826923122A8521Be36358Bdc53d3B4362B6f46E5;

    address public constant MAI_EXCHANGE = 0x0663C4b19D139b9582539f6053a9C69a2bCEBC9f;
    address public constant LENDING_POOL = 0xa6433855524027709FDfCA15937d9443d7989928;
    address public constant FLASH_MALL = 0x1f40465Dce9a07A5273b4b63F5f9C31ff2bcBD9a;
    address public constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public constant WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _usdtToMusd(uint256 amount) internal {
        IERC20Upgradeable(USDT).safeApprove(LENDING_POOL, amount);
        ILendingPool(LENDING_POOL).deposit(amount);
    }

    function _musdToUsdt(uint256 amount) internal {
        IERC20Upgradeable(MUSD).safeApprove(LENDING_POOL, amount);
        ILendingPool(LENDING_POOL).withdraw(amount);
    }

    function _musdToMcoin(uint256 amount) internal returns (uint256 outAmount) {
        IERC20Upgradeable(MUSD).safeApprove(FLASH_MALL, amount);
        IFlashMall(FLASH_MALL).pointMint(amount);
        outAmount = (amount * IFlashMall(FLASH_MALL).pointRate()) / 1000;
    }

    function _mcoinToMusd(uint256 amount) internal returns (uint256 outAmount) {
        IERC20Upgradeable(MCOIN).safeApprove(FLASH_MALL, amount);
        IFlashMall(FLASH_MALL).pointBack(amount);
        outAmount = (amount * 1000) / IFlashMall(FLASH_MALL).pointRate();
    }

    function _maiToMusd(uint256 amount) internal returns (uint256 outAmount) {
        IERC20Upgradeable(MAI).safeApprove(MAI_EXCHANGE, amount);
        IMaiExchange(MAI_EXCHANGE).withdraw(MUSD, amount);
        outAmount = (amount * IMaiExchange(MAI_EXCHANGE).lastPrice()) / 1e18;
    }

    function _usdtToBNB(uint256 amount, address to) internal {
        IERC20Upgradeable(USDT).approve(PANCAKE_ROUTER, amount);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = WETH;
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForETH(amount, 0, path, to, block.timestamp + 30);
    }

    function usdtToMusd(uint256 amount) external {
        IERC20Upgradeable(USDT).safeTransferFrom(msg.sender, address(this), amount);
        _usdtToMusd(amount);
        IERC20Upgradeable(MUSD).safeTransfer(msg.sender, amount);
    }

    function musdToUsdt(uint256 amount) external {
        IERC20Upgradeable(MUSD).safeTransferFrom(msg.sender, address(this), amount);
        _musdToUsdt(amount);
        IERC20Upgradeable(USDT).safeTransfer(msg.sender, amount);
    }

    function musdToMcoin(uint256 amount) external {
        IERC20Upgradeable(MUSD).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _musdToMcoin(amount);
        IERC20Upgradeable(MCOIN).safeTransfer(msg.sender, outAmount);
    }

    function mcoinToMusd(uint256 amount) external {
        IERC20Upgradeable(MCOIN).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _mcoinToMusd(amount);
        IERC20Upgradeable(MUSD).safeTransfer(msg.sender, outAmount);
    }

    function usdtToMcoin(uint256 amount) external {
        IERC20Upgradeable(USDT).safeTransferFrom(msg.sender, address(this), amount);
        _usdtToMusd(amount);
        uint256 outAmount = _musdToMcoin(amount);
        IERC20Upgradeable(MCOIN).safeTransfer(msg.sender, outAmount);
    }

    function mcoinToUsdt(uint256 amount) external {
        IERC20Upgradeable(MCOIN).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _mcoinToMusd(amount);
        _musdToUsdt(outAmount);
        IERC20Upgradeable(USDT).safeTransfer(msg.sender, outAmount);
    }

    function maiToMusd(uint256 amount) external {
        IERC20Upgradeable(MAI).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _maiToMusd(amount);
        IERC20Upgradeable(MUSD).safeTransfer(msg.sender, outAmount);
    }

    function maiToUsdt(uint256 amount) external {
        IERC20Upgradeable(MAI).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _maiToMusd(amount);
        _musdToUsdt(outAmount);
        IERC20Upgradeable(USDT).safeTransfer(msg.sender, outAmount);
    }

    function maiToMcoin(uint256 amount) external {
        IERC20Upgradeable(MAI).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _maiToMusd(amount);
        outAmount = _musdToMcoin(outAmount);
        IERC20Upgradeable(MCOIN).safeTransfer(msg.sender, outAmount);
    }

    function musdToBNB(uint256 amount) external {
        IERC20Upgradeable(MUSD).safeTransferFrom(msg.sender, address(this), amount);
        _musdToUsdt(amount);
        _usdtToBNB(amount, msg.sender);
    }

    function mcoinToBNB(uint256 amount) external {
        IERC20Upgradeable(MCOIN).safeTransferFrom(msg.sender, address(this), amount);
        uint256 outAmount = _mcoinToMusd(amount);
        _musdToUsdt(outAmount);
        _usdtToBNB(outAmount, msg.sender);
    }
}