// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../interfaces/IOdosRouter.sol";   
import "../interfaces/IUnoAssetRouter.sol";   
import "../interfaces/IUnoAutoStrategyFactory.sol";
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

contract UnoAutoStrategy is Initializable, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    /**
     * @dev PoolInfo:
     * {assetRouter} - UnoAssetRouter contract.
     * {pool} - Pool address. 
     * {tokenA} - Pool's first token address.
     * {tokenB} - Pool's second token address.
     */
    struct _PoolInfo {
        address pool;
        IUnoAssetRouter assetRouter;
    }

    struct PoolInfo {
        address pool;
        IUnoAssetRouter assetRouter;
        IERC20Upgradeable tokenA;
        IERC20Upgradeable tokenB;
    }

    /**
     * @dev MoveLiquidityInfo:
     * {leftoverA} - TokenA leftovers after MoveLiquidity() call.
     * {leftoverB} - TokenB leftovers after MoveLiquidity() call. 
     * {totalSupply} - totalSupply after MoveLiquidity() call.
     * {block} - MoveLiquidity() call block.
     */
    struct MoveLiquidityInfo {
        uint256 leftoverA;
        uint256 leftoverB;
        uint256 totalSupply;
        uint256 block;
    }
    
    /**
     * @dev Contract Variables:
     * {OdosRouter} - Contract that executes swaps.

     * {poolID} - Current pool the strategy uses ({pools} index).
     * {pools} - Pools this strategy can use and move liquidity to.

     * {reserveLP} - LP token reserve.
     * {lastMoveInfo} - Info on last MoveLiquidity() block.
     * {blockedLiquidty} - User's blocked LP tokens. Prevents user from stealing leftover tokens by depositing and exiting before moveLiquidity() has been called.
     * {leftoversCollected} - Flag that prevents leftover token collection if they were already collected this MoveLiquidity() cycle.

     * {accessManager} - Role manager contract.
     * {factory} - The address of AutoStrategyFactory this contract was deployed by.

     * {MINIMUM_LIQUIDITY} - Ameliorates rounding errors.
     */

    IOdosRouter private constant OdosRouter = IOdosRouter(0x9f138be5aA5cC442Ea7cC7D18cD9E30593ED90b9);

    uint256 public poolID;
    PoolInfo[] public pools;

    uint256 private reserveLP;
    MoveLiquidityInfo private lastMoveInfo;
    mapping(address => mapping(uint256 => uint256)) private blockedLiquidty;
    mapping(address => mapping(uint256 => bool)) private leftoversCollected;

    IUnoAccessManager public accessManager;
    IUnoAutoStrategyFactory public factory;

    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    bytes32 private constant LIQUIDITY_MANAGER_ROLE = keccak256('LIQUIDITY_MANAGER_ROLE');
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // Note: amountLP refers to LP tokens used in farms and staking pools, not UNO-LP this contract is.
    // To get info for UNO-LP use mint/burn events
    event Deposit(uint256 indexed poolID, address indexed from, address indexed recipient, uint256 amountLP);
    event Withdraw(uint256 indexed poolID, address indexed from, address indexed recipient, uint256 amountLP);
    event MoveLiquidity(uint256 indexed previousPoolID, uint256 indexed nextPoolID);

    modifier whenNotPaused(){
        require(factory.paused() == false, 'PAUSABLE: PAUSED');
        _;
    }

    // ============ Methods ============

    receive() external payable {}

    function initialize(_PoolInfo[] calldata poolInfos, IUnoAccessManager _accessManager) external initializer {
        require ((poolInfos.length >= 2) && (poolInfos.length <= 50), 'BAD_POOL_COUNT');

        __ERC20_init("UNO-AutoStrategy", "UNO-LP");
        __ReentrancyGuard_init();
        
        for (uint256 i = 0; i < poolInfos.length; i++) {
            address[] memory _tokens = IUnoAssetRouter(poolInfos[i].assetRouter).getTokens(poolInfos[i].pool);
            PoolInfo memory pool = PoolInfo({
                pool: poolInfos[i].pool,
                assetRouter: poolInfos[i].assetRouter,
                tokenA: IERC20Upgradeable(_tokens[0]),
                tokenB: IERC20Upgradeable(_tokens[1])
            });
            pools.push(pool);

            if (pool.tokenA.allowance(address(this), address(pool.assetRouter)) == 0) {
                pool.tokenA.approve(address(OdosRouter), type(uint256).max);
                pool.tokenA.approve(address(pool.assetRouter), type(uint256).max);
            }
            if (pool.tokenB.allowance(address(this), address(pool.assetRouter)) == 0) {
                pool.tokenB.approve(address(OdosRouter), type(uint256).max);
                pool.tokenB.approve(address(pool.assetRouter), type(uint256).max);
            }
        }

        accessManager = _accessManager;
        lastMoveInfo.block = block.number;
        factory = IUnoAutoStrategyFactory(msg.sender);
    }

    /**
     * @dev Deposits tokens in the pools[poolID] pool. Mints tokens representing user share. Emits {Deposit} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param amountA - Token A amount to deposit.
     * @param amountB  - Token B amount to deposit.
     * @param amountAMin - Bounds the extent to which the B/A price can go up before the transaction reverts.
     * @param amountBMin - Bounds the extent to which the A/B price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sentA - Deposited token A amount.
     * @return sentB - Deposited token B amount.
     * @return liquidity - Total liquidity minted for the {recipient}.
     */
    function deposit(uint256 pid, uint256 amountA, uint256 amountB, uint256 amountAMin, uint256 amountBMin, address recipient) whenNotPaused nonReentrant external returns (uint256 sentA, uint256 sentB, uint256 liquidity) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        pool.tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        pool.tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        uint256 amountLP;
        (sentA, sentB, amountLP) = pool.assetRouter.deposit(pool.pool, amountA, amountB, amountAMin, amountBMin, address(this));
        liquidity = mint(recipient);

        if(amountA > sentA){
            pool.tokenA.safeTransfer(msg.sender, amountA - sentA);
        }
        if(amountB > sentB){
            pool.tokenB.safeTransfer(msg.sender, amountB - sentB);
        }

        emit Deposit(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Deposits tokens in the pools[poolID] pool. Mints tokens representing user share. Emits {Deposit} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param amountToken - Token amount to deposit.
     * @param amountTokenMin - Bounds the extent to which the TOKEN/WBNB price can go up before the transaction reverts.
     * @param amountETHMin - Bounds the extent to which the WBNB/TOKEN price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sentToken - Deposited token amount.
     * @return sentETH - Deposited ETH amount.
     * @return liquidity - Total liquidity minted for the {recipient}.
     */
    function depositETH(uint256 pid, uint256 amountToken, uint256 amountTokenMin, uint256 amountETHMin, address recipient) whenNotPaused nonReentrant external payable returns (uint256 sentToken, uint256 sentETH, uint256 liquidity) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        IERC20Upgradeable token;
        if (address(pool.tokenA) == WBNB) {
            token = pool.tokenB;
        } else if (address(pool.tokenB) == WBNB) {
            token = pool.tokenA;
        } else {
            revert("NOT_WBNB_POOL");
        }
        token.safeTransferFrom(msg.sender, address(this), amountToken);

        uint256 amountLP;
        (sentToken, sentETH, amountLP) = pool.assetRouter.depositETH{value: msg.value}(pool.pool, amountToken, amountTokenMin, amountETHMin, address(this));
        liquidity = mint(recipient);

        if(amountToken > sentToken){
            token.safeTransfer(msg.sender, amountToken - sentToken);
        }
        if(msg.value > sentETH){
            payable(msg.sender).transfer(msg.value - sentETH);
        }
        emit Deposit(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Deposits tokens in the pools[poolID] pool. Mints tokens representing user share. Emits {Deposit} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param token - Token to deposit.
     * @param amount - {token} amount to deposit.
     * @param swapData - Parameter with which 1inch router is being called with.
     * @param amountAMin - Bounds the extent to which the B/A price can go up before the transaction reverts.
     * @param amountBMin - Bounds the extent to which the A/B price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sent - Total {token} amount sent to the farm. NOTE: Returns dust left from swap in {token}, but if A/B amounts are not correct also returns dust in pool's tokens.
     * @return liquidity - Total liquidity minted for the {recipient}.
     */
    function depositSingleAsset(uint256 pid, address token, uint256 amount, bytes[2] calldata swapData, uint256 amountAMin, uint256 amountBMin, address recipient) whenNotPaused nonReentrant external returns (uint256 sent, uint256 liquidity) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        uint256 balanceA = pool.tokenA.balanceOf(address(this));
        uint256 balanceB = pool.tokenB.balanceOf(address(this));

        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20Upgradeable(token).approve(address(pool.assetRouter), amount);

        uint256 amountLP;
        (sent, amountLP) = pool.assetRouter.depositSingleAsset(pool.pool, token, amount, swapData, amountAMin, amountBMin, address(this));
        liquidity = mint(recipient);

        IERC20Upgradeable(token).safeTransfer(msg.sender, amount - sent);
        uint256 _balanceA = pool.tokenA.balanceOf(address(this));
        uint256 _balanceB = pool.tokenB.balanceOf(address(this));
        if(_balanceA > balanceA){
            pool.tokenA.safeTransfer(msg.sender, _balanceA - balanceA);
        }
        if(_balanceB > balanceB){
            pool.tokenB.safeTransfer(msg.sender, _balanceB - balanceB);
        }

        emit Deposit(poolID, msg.sender, recipient, amountLP);
    }

    /**
     * @dev Deposits tokens in the pools[poolID] pool. Mints tokens representing user share. Emits {Deposit} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param swapData - Parameter with which 1inch router is being called with. NOTE: Use WBNB as toToken.
     * @param amountAMin - Bounds the extent to which the B/A price can go up before the transaction reverts.
     * @param amountBMin - Bounds the extent to which the A/B price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sentETH - Total BNB amount sent to the farm. NOTE: Returns dust left from swap in BNB, but if A/B amount are not correct also returns dust in pool's tokens.
     * @return liquidity - Total liquidity minted for the {recipient}.
     */
    function depositSingleETH(uint256 pid, bytes[2] calldata swapData, uint256 amountAMin, uint256 amountBMin, address recipient) whenNotPaused nonReentrant external payable returns (uint256 sentETH, uint256 liquidity) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        uint256 balanceA = pool.tokenA.balanceOf(address(this));
        uint256 balanceB = pool.tokenB.balanceOf(address(this));

        uint256 amountLP;
        (sentETH, amountLP) = pool.assetRouter.depositSingleETH{value: msg.value}(pool.pool, swapData, amountAMin, amountBMin, address(this));
        liquidity = mint(recipient);

        payable(msg.sender).transfer(msg.value - sentETH);
        uint256 _balanceA = pool.tokenA.balanceOf(address(this));
        uint256 _balanceB = pool.tokenB.balanceOf(address(this));
        if(_balanceA > balanceA){
            pool.tokenA.safeTransfer(msg.sender, _balanceA - balanceA);
        }
        if(_balanceB > balanceB){
            pool.tokenB.safeTransfer(msg.sender, _balanceB - balanceB);
        }

        emit Deposit(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Withdraws tokens from the {pools[poolID]} pool and sends them to the recipient. Burns tokens representing user share. Emits {Withdraw} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param liquidity - Liquidity to burn from this user.
     * @param amountAMin - The minimum amount of tokenA that must be received from the pool for the transaction not to revert.
     * @param amountBMin - The minimum amount of tokenB that must be received from the pool for the transaction not to revert.
     * @param recipient - Address which will receive withdrawn tokens.
     
     * @return amountA - Token A amount sent to the {recipient}.
     * @return amountB - Token B amount sent to the {recipient}.
     */
    function withdraw(uint256 pid, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address recipient) whenNotPaused nonReentrant external returns (uint256 amountA, uint256 amountB) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        (uint256 leftoverA, uint256 leftoverB) = collectLeftovers(recipient);

        uint256 amountLP = burn(liquidity);
        (amountA, amountB) = pool.assetRouter.withdraw(pool.pool, amountLP, amountAMin, amountBMin, recipient);

        amountA += leftoverA;
        amountB += leftoverB;

        emit Withdraw(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Withdraws tokens from the {pools[poolID]} pool and sends them to the recipient. Burns tokens representing user share. Emits {Withdraw} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param liquidity - Liquidity to burn from this user.
     * @param amountTokenMin - The minimum amount of tokenA that must be received from the pool for the transaction not to revert.
     * @param amountETHMin - The minimum amount of tokenB that must be received from the pool for the transaction not to revert.
     * @param recipient - Address which will receive withdrawn tokens.
     
     * @return amountToken - Token amount sent to the {recipient}.
     * @return amountETH - BNB amount sent to the {recipient}.
     */
    function withdrawETH(uint256 pid, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, address recipient) whenNotPaused nonReentrant external returns (uint256 amountToken, uint256 amountETH) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        (uint256 leftoverA, uint256 leftoverB) = collectLeftovers(recipient);

        uint256 amountLP = burn(liquidity);
        (amountToken, amountETH) = pool.assetRouter.withdrawETH(pool.pool, amountLP, amountTokenMin, amountETHMin, recipient);

        if (address(pool.tokenA) == WBNB) {
            amountETH += leftoverA;
            amountToken += leftoverB;
        } else if (address(pool.tokenB) == WBNB) {
            amountToken += leftoverA;
            amountETH += leftoverB;
        } else {
            revert("NOT_WBNB_POOL");
        }
        emit Withdraw(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Withdraws tokens from the {pools[poolID]} pool and sends them to the recipient. Burns tokens representing user share. Emits {Withdraw} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param liquidity - Liquidity to burn from this user.
     * @param token - Address of a token to exit the pool with.
     * @param swapData - Parameter with which 1inch router is being called with.
     * @param recipient - Address which will receive withdrawn tokens.
     
     * @return amountToken - {token} amount sent to the {recipient}.
     * @return amountA - Token A dust sent to the {recipient}.
     * @return amountB - Token B dust sent to the {recipient}.
     */
    function withdrawSingleAsset(uint256 pid, uint256 liquidity, address token, bytes[2] calldata swapData, address recipient) whenNotPaused nonReentrant external returns (uint256 amountToken, uint256 amountA, uint256 amountB) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        (uint256 leftoverA, uint256 leftoverB) = collectLeftovers(recipient);

        uint256 amountLP = burn(liquidity);
        (amountToken, amountA, amountB) = pool.assetRouter.withdrawSingleAsset(pool.pool, amountLP, token, swapData, recipient);

        amountA += leftoverA;
        amountB += leftoverB;

        emit Withdraw(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Withdraws tokens from the {pools[poolID]} pool and sends them to the recipient. Burns tokens representing user share. Emits {Withdraw} event.
     * @param pid - Current poolID. Throws revert if moveLiquidity() has been called before the transaction has been mined.
     * @param liquidity - Liquidity to burn from this user.
     * @param swapData - Parameter with which 1inch router is being called with.
     * @param recipient - Address which will receive withdrawn tokens.
     
     * @return amountETH - BNB amount sent to the {recipient}.
     * @return amountA - Token A dust sent to the {recipient}.
     * @return amountB - Token B dust sent to the {recipient}.
     */
    function withdrawSingleETH(uint256 pid, uint256 liquidity, bytes[2] calldata swapData, address recipient) whenNotPaused nonReentrant external returns (uint256 amountETH, uint256 amountA, uint256 amountB) {
        require (pid == poolID, 'BAD_POOL_ID');
        PoolInfo memory pool = pools[poolID];

        (uint256 leftoverA, uint256 leftoverB) = collectLeftovers(recipient);

        uint256 amountLP = burn(liquidity);
        (amountETH, amountA, amountB) = pool.assetRouter.withdrawSingleETH(pool.pool, amountLP, swapData, recipient);

        amountA += leftoverA;
        amountB += leftoverB;

        emit Withdraw(poolID, msg.sender, recipient, amountLP); 
    }

    /**
     * @dev Collects leftover tokens left from moveLiquidity() function.
     * @param recipient - Address which will receive leftover tokens.
     
     * @return leftoverA - Token A amount sent to the {recipient}.
     * @return leftoverB - Token B amount sent to the {recipient}.
     */
    function collectLeftovers(address recipient) internal returns (uint256 leftoverA, uint256 leftoverB){
        if(!leftoversCollected[msg.sender][lastMoveInfo.block]){
            if(lastMoveInfo.totalSupply != 0){
                PoolInfo memory pool = pools[poolID];
                leftoverA = (balanceOf(msg.sender) - blockedLiquidty[msg.sender][lastMoveInfo.block]) * lastMoveInfo.leftoverA / lastMoveInfo.totalSupply;
                leftoverB = (balanceOf(msg.sender) - blockedLiquidty[msg.sender][lastMoveInfo.block]) * lastMoveInfo.leftoverB / lastMoveInfo.totalSupply;

                if(leftoverA > 0){
                    pool.tokenA.safeTransfer(recipient, leftoverA);
                }
                if(leftoverB > 0){
                    pool.tokenB.safeTransfer(recipient, leftoverB);
                }
            }

            leftoversCollected[msg.sender][lastMoveInfo.block] = true;
        }
    }

    /**
     * @dev Moves liquidity from {pools[poolID]} to {pools[_poolID]}. Emits {MoveLiquidity} event.
     * @param _poolID - Pool ID to move liquidity to.
     * @param swapAData - Data for tokenA swap.
     * @param swapBData - Data for tokenB swap.
     * @param amountAMin - The minimum amount of tokenA that must be deposited in {pools[_poolID]} for the transaction not to revert.
     * @param amountBMin - The minimum amount of tokenB that must be deposited in {pools[_poolID]} for the transaction not to revert.
     *
     * Note: This function can only be called by LiquidityManager.
     */
    function moveLiquidity(uint256 _poolID, bytes calldata swapAData, bytes calldata swapBData, uint256 amountAMin, uint256 amountBMin) whenNotPaused nonReentrant external {
        require(accessManager.hasRole(LIQUIDITY_MANAGER_ROLE, msg.sender), 'CALLER_NOT_LIQUIDITY_MANAGER');
        require(totalSupply() != 0, 'NO_LIQUIDITY');
        require(lastMoveInfo.block != block.number, 'CANT_CALL_ON_THE_SAME_BLOCK');
        require((_poolID < pools.length) && (_poolID != poolID), 'BAD_POOL_ID');

        PoolInfo memory currentPool = pools[poolID];
        PoolInfo memory newPool = pools[_poolID];

        (uint256 _totalDeposits,,) = currentPool.assetRouter.userStake(address(this), currentPool.pool);
        currentPool.assetRouter.withdraw(currentPool.pool, _totalDeposits, 0, 0, address(this));

        uint256 tokenABalance = currentPool.tokenA.balanceOf(address(this));
        uint256 tokenBBalance = currentPool.tokenB.balanceOf(address(this));

        if(currentPool.tokenA != newPool.tokenA){
            (
                IOdosRouter.inputToken[] memory inputs, 
                IOdosRouter.outputToken[] memory outputs, 
                ,
                uint256 valueOutMin,
                address executor,
                bytes memory pathDefinition
            ) = abi.decode(swapAData[4:], (IOdosRouter.inputToken[],IOdosRouter.outputToken[],uint256,uint256,address,bytes));

            require((inputs.length == 1) && (outputs.length == 1), 'BAD_SWAP_A_TOKENS_LENGTH');
            require(inputs[0].tokenAddress == address(currentPool.tokenA), 'BAD_SWAP_A_INPUT_TOKEN');
            require(outputs[0].tokenAddress == address(newPool.tokenA), 'BAD_SWAP_A_OUTPUT_TOKEN');

            inputs[0].amountIn = tokenABalance;
            OdosRouter.swap(inputs, outputs, type(uint256).max, valueOutMin, executor, pathDefinition);
        }

        if(currentPool.tokenB != newPool.tokenB){
            (
                IOdosRouter.inputToken[] memory inputs,
                IOdosRouter.outputToken[] memory outputs,
                ,
                uint256 valueOutMin,
                address executor,
                bytes memory pathDefinition
            ) = abi.decode(swapBData[4:], (IOdosRouter.inputToken[],IOdosRouter.outputToken[],uint256,uint256,address,bytes));

            require((inputs.length == 1) && (outputs.length == 1), 'BAD_SWAP_B_TOKENS_LENGTH');
            require(inputs[0].tokenAddress == address(currentPool.tokenB), 'BAD_SWAP_B_INPUT_TOKEN');
            require(outputs[0].tokenAddress == address(newPool.tokenB), 'BAD_SWAP_B_OUTPUT_TOKEN');

            inputs[0].amountIn = tokenBBalance;
            OdosRouter.swap(inputs, outputs, type(uint256).max, valueOutMin, executor, pathDefinition);
        }
        
        (,,reserveLP) = newPool.assetRouter.deposit(newPool.pool, newPool.tokenA.balanceOf(address(this)), newPool.tokenB.balanceOf(address(this)), amountAMin, amountBMin, address(this));
       
        lastMoveInfo = MoveLiquidityInfo({
            leftoverA: newPool.tokenA.balanceOf(address(this)),
            leftoverB: newPool.tokenB.balanceOf(address(this)),
            totalSupply: totalSupply(),
            block: block.number
        });

        emit MoveLiquidity(poolID, _poolID); 
        poolID = _poolID;
    }

    /**
     * @dev Returns tokens staked by the {_address}. 
     * @param _address - The address to check stakes for.

     * @return stakeA - Token A stake.
     * @return stakeB - Token B stake.
     * @return leftoverA - Token A Leftovers obligated to the {_address} after moveLiquidity() function call.
     * @return leftoverB - Token B Leftovers obligated to the {_address} after moveLiquidity() function call.
     */
    function userStake(address _address) external view returns (uint256 stakeA, uint256 stakeB, uint256 leftoverA, uint256 leftoverB) {
        PoolInfo memory pool = pools[poolID];
        (, uint256 balanceA, uint256 balanceB) = pool.assetRouter.userStake(address(this), pool.pool);

        uint256 _balance = balanceOf(_address);
        if(_balance != 0){
            uint256 _totalSupply = totalSupply();
            stakeA = _balance * balanceA / _totalSupply; 
            stakeB = _balance * balanceB / _totalSupply; 
            if((!leftoversCollected[msg.sender][lastMoveInfo.block]) && (lastMoveInfo.totalSupply != 0)){
                leftoverA = (_balance - blockedLiquidty[_address][lastMoveInfo.block]) * lastMoveInfo.leftoverA / lastMoveInfo.totalSupply;
                leftoverB = (_balance - blockedLiquidty[_address][lastMoveInfo.block]) * lastMoveInfo.leftoverB / lastMoveInfo.totalSupply;
            }
        }
    }
        
    /**
     * @dev Returns total amount locked in the pool. 
     * @return totalDepositsA - Token A deposits.
     * @return totalDepositsB - Token B deposits.
     */     
    function totalDeposits() external view returns(uint256 totalDepositsA, uint256 totalDepositsB){
        PoolInfo memory pool = pools[poolID];
        (, totalDepositsA, totalDepositsB) = pool.assetRouter.userStake(address(this), pool.pool);

        // Add leftover tokens.
        totalDepositsA += pool.tokenA.balanceOf(address(this));
        totalDepositsB += pool.tokenB.balanceOf(address(this));
    }

    /**
     * @dev Returns the number of pools in the strategy. 
     */
    function poolsLength() external view returns(uint256){
        return pools.length;
    }

    /**
     * @dev Returns pair of tokens currently in use. 
     */
    function tokens() external view returns(address, address){
        PoolInfo memory pool = pools[poolID];
        return (address(pool.tokenA), address(pool.tokenB));
    }

    function mint(address to) internal returns (uint256 liquidity){
        PoolInfo memory pool = pools[poolID];
        (uint256 balanceLP,,) = pool.assetRouter.userStake(address(this), pool.pool);
        uint256 amountLP = balanceLP - reserveLP;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = amountLP - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            liquidity = amountLP * _totalSupply / reserveLP;
        }

        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        reserveLP = balanceLP;
    }

    function burn(uint256 liquidity) internal returns (uint256 amountLP) {
        PoolInfo memory pool = pools[poolID];
        (uint256 balanceLP,,) = pool.assetRouter.userStake(address(this), pool.pool);

        amountLP = liquidity * balanceLP / totalSupply(); 
        require(amountLP > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(msg.sender, liquidity);

        reserveLP = balanceLP - amountLP;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        // Decrease blockedLiquidty from {from} address, but no less then 0.
        if(amount > blockedLiquidty[from][lastMoveInfo.block]){
            blockedLiquidty[from][lastMoveInfo.block] = 0;
        } else {
            blockedLiquidty[from][lastMoveInfo.block] -= amount;
        }
        // Block {to} address from withdrawing their share of leftover tokens immediately.
        blockedLiquidty[to][lastMoveInfo.block] += amount;
    }
}