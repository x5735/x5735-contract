// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILeechTransporter.sol";
import "./interfaces/ILeechStrategy.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title A LeechProtocol Router
/// @notice The Router is the main protocol contract, for user interactions and protocol automatizations.
contract LeechRouter is
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    ///@dev Struct for the strategy instance
    struct Strategy {
        uint256 id;
        uint256 poolId;
        uint256 chainId;
        address strategyAddress;
        bool isLp;
        uint256 withdrawalFee;
    }

    ///@dev Struct for the Vault instance
    struct Pool {
        uint256 id;
        string name;
    }

    ///@dev Struct for the Router instance
    struct Router {
        uint256 id;
        uint256 chainId;
        address routerAddress;
    }

    ///@notice Bridge interface abstraction
    ILeechTransporter public transporter;

    ///@notice base protocol stablecoin
    IERC20 public baseToken;

    ///@notice chain ID of the current network
    uint256 public chainId;

    ///@notice 20% withdrawal fee limitation
    uint256 public constant FEE_MAX = 2000;

    ///@notice withdrawal fee decimals
    uint256 public constant FEE_DECIMALS = 10000;

    ///@notice Access Control roles
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    ///@dev Mapping for disabling malicious actors
    mapping(address => bool) private _banned;

    ///@notice Mapping will return active strategy struct for the specific pool id
    mapping(uint256 => Strategy) public poolIdtoActiveStrategy;

    ///@notice Mapping will return active router struct for the specifi chain id.
    ///@dev Used for the crosschain transactions
    mapping(uint256 => Router) public chainIdToRouter;

    ///@notice ECDSA validator address
    address public signer;

    ///@notice Protocol fee receiver
    address public treasury;

    ///@notice Uniswap based router for simple exchanges
    address public uniV2;

    ///@notice Switcher for the signature based input validation
    bool whitelistEnabled;

    ///@notice Modifier allows exlude banned addresses from execution, even if the valid signature exists.
    modifier enabled(address user) {
        if (_banned[user]) revert("Banned");
        _;
    }

    ///@dev Emit in cross-chain deposits.
    event BaseBridged(
        address user,
        uint256 amountOfBase,
        uint256 poolId,
        uint256 strategyId,
        uint256 destinationChainId,
        uint256 fromChainId,
        address depositedToken
    );

    ///@dev Emit after deposit to the strategy.
    event Deposited(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 chainId,
        uint256 wantAmountDeposited,
        address depositedToken
    );

    ///@dev Emit in request withdraw function to notify back-end.
    event WithdrawalRequested(
        address user,
        uint256 poolId,
        uint256 amount,
        uint256 chainId,
        address tokenOut
    );

    ///@dev Emit after completeing withdrawal requests.
    event WithdrawCompleted(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 targetChainId,
        uint256 wantAmount
    );

    ///@dev Emit after completeing cross-chain withdrawal requests.
    event CrosschainWithdrawCompleted(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 targetChainId,
        uint256 wantAmount
    );

    ///@dev Emit after cross-chain migration is completed.
    event FinalizedCrosschainMigration(
        uint256 poolId,
        uint256 strategyId,
        uint256 chainId
    );

    ///@dev Start migration. If migration is not cross-chain this event is complete.
    event Migration(uint256 poolId, uint256 strategyId, uint256 chainId);

    /**
     *@notice Initializer.
     *@param _baseToken Base stablecoin.
     *@param _uniV2Address Dex router address.
     */
    function initialize(
        address _baseToken,
        address _uniV2Address
    ) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(SERVER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UNPAUSER_ROLE, msg.sender);

        baseToken = IERC20(_baseToken);
        uniV2 = _uniV2Address;

        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }
        chainId = _chainId;

        whitelistEnabled = true;
        treasury = msg.sender;
        signer = msg.sender;
    }

    /**
     *@notice User deposit method.
     *@param signature Signed message by the back-end.
     *@param poolId Selected pool ID.
     *@param depositToken Deposited token address.
     *@param amount Amount of deposited token.
     *@param maxBlockNumber Max block for the signature expiring.
     *@param path Exchanche path.
     * Path parameter can have two options:
     * tokenInToToken0 if current chain is active strategy
     * tokenInToBase if cerrent chain isn't active and bridging reqiured
     */
    function deposit(
        bytes calldata signature,
        uint16 poolId,
        IERC20 depositToken,
        uint256 amount,
        uint256 maxBlockNumber,
        address[] calldata path
    ) external enabled(msg.sender) whenNotPaused nonReentrant {
        if (whitelistEnabled) {
            // Signature verification
            bytes32 msgHash = keccak256(
                abi.encode(msg.sender, maxBlockNumber, amount, chainId, poolId)
            );
            require(
                msgHash.toEthSignedMessageHash().recover(signature) == signer,
                "not allowed"
            );
            if (block.number > maxBlockNumber) revert("Signature expired");
        } else {
            bytes32 msgHash = keccak256(
                abi.encode(amount, chainId, poolId)
            );
            require(
                msgHash.toEthSignedMessageHash().recover(signature) == signer,
                "not allowed"
            );
        }

        //Need custom revert for safeERC20
        if (
            depositToken.balanceOf(msg.sender) < amount ||
            depositToken.allowance(msg.sender, address(this)) < amount
        ) revert("Wrong balance or allowance");

        //Validate if the selected pool is active
        Strategy storage activeStrat = poolIdtoActiveStrategy[poolId];
        require(activeStrat.chainId != 0, "empty pool");

        if (chainId == activeStrat.chainId) {
            // if current chain is active, deposit to strategy
            depositToken.safeTransferFrom(
                msg.sender,
                activeStrat.strategyAddress,
                amount
            );
            uint256 deposited = ILeechStrategy(activeStrat.strategyAddress)
                .deposit(path);

            emit Deposited(
                msg.sender,
                poolId,
                activeStrat.id,
                chainId,
                deposited,
                address(depositToken)
            );
        } else {
            depositToken.safeTransferFrom(msg.sender, address(this), amount);

            //swap to base if needed
            if (address(depositToken) != address(baseToken)) {
                uint256[] memory swapedAmounts = _swap(amount, path);

                amount = swapedAmounts[swapedAmounts.length - 1];
            }

            baseToken.safeTransfer(address(transporter), amount);

            Router memory router = chainIdToRouter[activeStrat.chainId];

            transporter.bridgeOut(
                address(baseToken),
                amount,
                activeStrat.chainId,
                router.routerAddress
            );

            emit BaseBridged(
                msg.sender,
                amount,
                poolId,
                activeStrat.id,
                activeStrat.chainId,
                chainId,
                address(depositToken)
            );
        }
    }

    /**
     *@notice User creates withdrawal request.
     *@notice Due to the cross-chain architecture of the protocol, share prices are stored on the BE side.
     *@param signature Signed message by the back-end.
     *@param poolId Selected pool ID.
     *@param tokenOut Withdrwalas token address. Filtering on the BE side.
     *@param amount Amount of withdrawal token.
     *@param maxBlockNumber Max block for the signature expiring.
     */
    function withdraw(
        bytes calldata signature,
        uint16 poolId,
        address tokenOut,
        uint256 amount,
        uint256 maxBlockNumber
    ) external enabled(msg.sender) whenNotPaused {
        //Validate if the selected pool is active
        Strategy storage activeStrat = poolIdtoActiveStrategy[poolId];
        require(activeStrat.chainId != 0, "empty pool");

        if (whitelistEnabled) {
            //Share tokens are located in the DB
            //Signature verification
            bytes32 msgHash = keccak256(
                abi.encode(msg.sender, maxBlockNumber, amount, chainId, poolId)
            );

            require(
                msgHash.toEthSignedMessageHash().recover(signature) == signer,
                "not allowed"
            );

            if (block.number > maxBlockNumber) revert("Signature expired");
        } else {
            bytes32 msgHash = keccak256(
                abi.encode(amount, chainId, poolId)
            );
            require(
                msgHash.toEthSignedMessageHash().recover(signature) == signer,
                "not allowed"
            );
        }

        emit WithdrawalRequested(msg.sender, poolId, amount, chainId, tokenOut);
    }

    /**
     *@notice After bridging completed we need to place tokens to farm.
     *@notice Used only to finalize cross-chain deposits.
     *@param user User address who performed a cross-chain deposit.
     *@param amount Amount of base token.
     *@param poolId Pool Id.
     *@param pathBaseToToken0 Path for the exchange from base token to token0 strategy token.
     */
    function placeToFarm(
        address user,
        uint256 amount,
        uint256 poolId,
        address[] calldata pathBaseToToken0,
        address depositToken
    ) external onlyRole(SERVER_ROLE) whenNotPaused {
        require(amount > 0, "zero amount");
        require(user != address(0), "zero address");

        Strategy storage activeStrat = poolIdtoActiveStrategy[poolId];
        baseToken.safeTransfer(activeStrat.strategyAddress, amount);
        uint256 deposited = ILeechStrategy(activeStrat.strategyAddress).deposit(
            pathBaseToToken0
        );

        emit Deposited(user, poolId, activeStrat.id, chainId, deposited, depositToken);
    }

    /**
     *@notice BE calls after WithdrawalRequested event was catched
     *@notice Should be called on chain with active strategy
     *@param poolId Pool Id.
     *@param amount Amount in "want" token on strategy: LP or single token.
     *@param user User address.
     *@param token0ToTokenOut Path for the exchange from token0 strategy token to the requested token.
     *@param token1ToTokenOut Additional argument for LP based strategies. Should include zero address in array for single pools.
     *@param targetChainId Chain ID of the network where the withdrawal requests was created.
     */
    function initWithdrawal(
        uint256 poolId,
        uint256 amount,
        address user,
        address[] calldata token0ToTokenOut,
        address[] calldata token1ToTokenOut,
        uint256 targetChainId
    ) external onlyRole(SERVER_ROLE) whenNotPaused {
        require(amount > 0, "zero amount");
        require(user != address(0), "zero address");

        //Take strat instance by pool id
        Strategy storage activeStrat = poolIdtoActiveStrategy[poolId];
        address tokenOut = token0ToTokenOut[token0ToTokenOut.length - 1];

        //Withdraw tokenOut token from strategy and receive uint256 amount of received token
        uint256 tokenOutAmount = ILeechStrategy(activeStrat.strategyAddress)
            .withdraw(amount, token0ToTokenOut, token1ToTokenOut);

        //Minus fee if needed
        if (activeStrat.withdrawalFee > 0) {
            IERC20(tokenOut).safeTransfer(
                treasury,
                (tokenOutAmount * activeStrat.withdrawalFee) / FEE_DECIMALS
            );

            tokenOutAmount =
                tokenOutAmount -
                (tokenOutAmount * activeStrat.withdrawalFee) /
                FEE_DECIMALS;
        }

        //sending tokens to user directly or via bridge
        if (targetChainId == chainId) {
            //if requested on current chain, send tokens
            IERC20(tokenOut).safeTransfer(user, tokenOutAmount);
            emit WithdrawCompleted(
                user,
                poolId,
                activeStrat.id,
                targetChainId,
                amount
            );
        } else {
            //if requested on another chain, use bridge
            IERC20(tokenOut).safeTransfer(address(transporter), tokenOutAmount);

            transporter.bridgeOut(
                tokenOut,
                tokenOutAmount,
                targetChainId,
                user
            );
            emit CrosschainWithdrawCompleted(
                user,
                poolId,
                activeStrat.id,
                targetChainId,
                amount
            );
        }
    }

    /**
     *@notice 1st step for change strategy.
     *@notice Should be called only on active strategy chain.
     *If new strategy in the same chain, the migration is complete.
     *If new strategy in another network, finalizeCrosschainMigration should be call after bridging.
     *@param poolId Pool Id to be migrated.
     *@param _strategy Tupple of the new strategy.
     *@param path Path from the base stable token to the token0 of the new strategy.
     */
    function initMigration(
        uint256 poolId,
        Strategy calldata _strategy,
        address[] calldata path
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_strategy.poolId == poolId, "wrong parameters");
        require(_strategy.strategyAddress != address(0), "empty strategy");

        Strategy memory _currentStrategy = poolIdtoActiveStrategy[poolId];

        require(_currentStrategy.chainId == chainId, "wrong chain");

        uint256 balanceBefore = baseToken.balanceOf(address(this));
        ILeechStrategy(_currentStrategy.strategyAddress).withdrawAll();
        uint256 withdrawAmount = baseToken.balanceOf(address(this)) -
            balanceBefore;

        if (_strategy.chainId == chainId) {
            baseToken.safeTransfer(_strategy.strategyAddress, withdrawAmount);
            ILeechStrategy(_strategy.strategyAddress).deposit(path);
        } else {
            Router memory _router = chainIdToRouter[_strategy.chainId];
            baseToken.safeTransfer(address(transporter), withdrawAmount);

            transporter.bridgeOut(
                address(baseToken),
                withdrawAmount,
                _strategy.chainId,
                _router.routerAddress
            );
        }

        poolIdtoActiveStrategy[poolId] = _strategy;

        emit Migration(poolId, _strategy.id, chainId);
    }

    /**
     *@notice 2nd additional step for change strategy
     *@notice Should be called only if cross-chain migration was initialized.
     *@param poolId Pool Id to be migrated.
     *@param _strategy Tupple of the new strategy.
     *@param baseAmount Migrated amount in base stable token.
     *@param path Path from the base stable token to the token0 of the new strategy.
     */
    function finalizeCrosschainMigration(
        uint256 poolId,
        Strategy calldata _strategy,
        uint256 baseAmount,
        address[] calldata path
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_strategy.poolId == poolId, "wrong parameters");
        require(_strategy.strategyAddress != address(0), "empty strategy");
        require(_strategy.chainId == chainId, "wrong chain");

        baseToken.safeTransfer(_strategy.strategyAddress, baseAmount);
        ILeechStrategy(_strategy.strategyAddress).deposit(path);

        poolIdtoActiveStrategy[poolId] = _strategy;

        emit FinalizedCrosschainMigration(poolId, _strategy.id, chainId);
    }

    /**
     *@notice Signer setter. Only multisig role.
     *@param _signer New signer.
     */
    function setSigner(address _signer) external onlyRole(ADMIN_ROLE) {
        require(_signer != address(0), "Zero address");
        signer = _signer;
    }

    /**
     *@notice Strategy setter. Only multisig role.
     *@dev Should be invoked with special caution to prevent overriding active strategies.
     *@dev For the active strategies with non-zero ballance migration should be used.
     *@param poolId Pool Id.
     *@param _strategy Tupple of the new strategy.
     */
    function setStrategy(
        uint256 poolId,
        Strategy calldata _strategy
    ) external onlyRole(ADMIN_ROLE) {
        require(poolId == _strategy.poolId, "different pools");
        require(_strategy.withdrawalFee <= FEE_MAX, "different pools");
        poolIdtoActiveStrategy[poolId] = _strategy;
    }

    /**
     *@notice Router setter. Only multisig role.
     *@dev Should be invoked with special caution to prevent overriding active routers.
     *@param _chainId Chain Id.
     *@param _router Tupple of the router.
     */
    function setRouter(
        uint256 _chainId,
        Router calldata _router
    ) external onlyRole(ADMIN_ROLE) {
        chainIdToRouter[_chainId] = _router;
    }

    /**
     *@notice Transporter setter. Only multisig role.
     *@dev Should be invoked with special caution to prevent blocking cross-chain operations.
     *@param _transporter New transporter.
     */
    function setTransporter(
        address _transporter
    ) external onlyRole(ADMIN_ROLE) {
        require(_transporter != address(0), "Zero address");
        transporter = ILeechTransporter(_transporter);
    }

    ///@notice Enable pause.
    function setPause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    ///@notice Disable pause. Only multisig role.
    function setUnpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    ///@notice On/Off signature based validation. Only multisig role.
    function switchWhitelistStatus() external onlyRole(ADMIN_ROLE) {
        if (whitelistEnabled) whitelistEnabled = false;
        else whitelistEnabled = true;
    }

    ///@notice Should be used for emergencies only. Only multisig role.
    function rescueERC20(address _token) external onlyRole(ADMIN_ROLE) {
        IERC20(_token).safeTransfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }

    /**
     *@notice Uniswap based router setter. Only multisig role.
     *@dev Should be invoked with special caution to prevent blocking cross-chain operations.
     *@param _uniV2Address New uniV2 address.
     */
    function setUniV2(address _uniV2Address) external onlyRole(ADMIN_ROLE) {
        require(_uniV2Address != address(0), "Zero address");
        uniV2 = _uniV2Address;
    }

    /**
     *@notice Fee receiver setter. Only multisig role.
     *@param _treasury New treasury address.
     */
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "Zero address");
        treasury = _treasury;
    }

    /**
     *@notice Function for disable and enable specific user
     *@param _user User addess
     *@param _status Boolean status
     */
    function setBanned(address _user, bool _status) external onlyRole(ADMIN_ROLE) {
        _banned[_user] = _status;
    }

    /**
     *@notice Return true if user was banned.
     *@param user User address.
     */
    function isBanned(address user) external view returns (bool) {
        return _banned[user];
    }

    /**
     *@dev Use uniswapV2Router for simple swaps. Used for the cross-chain operations.
     *@param _amount TokenIn amount.
     *@param path Path to tokenOut
     */
    function _swap(
        uint256 _amount,
        address[] calldata path
    ) private returns (uint256[] memory swapedAmounts) {
        _approveIfNeeded(IERC20(path[0]), uniV2);
        swapedAmounts = IUniswapV2Router02(uniV2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     *@dev Approve tokens for external contract.
     *@param token token instance.
     *@param to address to be approved.
     */
    function _approveIfNeeded(IERC20 token, address to) private {
        if (token.allowance(address(this), to) == 0) {
            token.safeApprove(address(to), type(uint256).max);
        }
    }
}