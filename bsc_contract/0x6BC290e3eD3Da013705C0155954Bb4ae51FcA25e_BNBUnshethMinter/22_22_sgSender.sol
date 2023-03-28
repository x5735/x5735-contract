pragma solidity ^0.8.0;

import "layerzerolabs/contracts/token/oft/OFT.sol";
import "layerzerolabs/contracts/interfaces/IStargateRouter.sol";
import "communal/Owned.sol";
import "communal/TransferHelper.sol";

// PancakeSwap Router interface for token swaps
interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint256 deadline) external payable returns (uint256[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

contract BNBUnshethMinter is Owned {

    address usdtAddress;                    // address of the binanced pegged usdt
    address stargateRouterAddress;          // address of the stargate router
    address ethAddress;                    // address for the binance pegged eth token
    address pancakeSwapRouterAddress;       // address for the pancake swap router
    uint16 dstChainId;                      // Stargate/LayerZero chainId
    uint16 srcPoolId;                       // stargate poolId - *must* be the poolId for the qty asset
    uint16 dstPoolId;                       // stargate destination poolId
    uint256 stargateGasAmount;              // amount of gas to send over stargate when minting unshETH
    address destStargateComposed;           // destination contract. it must implement sgReceive()
    bool paused = false;

    IUniswapV2Router02 private pancakeSwapRouter;

    // Constructor sets up contract dependencies and initializes parent contract OFT
    constructor(
        address _owner, //address of the user deploying this contract
        address _ethAddress, //address of ETH on BNB - 0x2170ed0880ac9a755fd29b2688956bd959f933f8
        address _pancakeSwapRouterAddress, //0x10ED43C718714eb63d5aA57B78B54704E256024E as per https://docs.pancakeswap.finance/code/smart-contracts/pancakeswap-exchange/v2/router-v2
        address _usdtAddress, //address of USDT on BNB - 0x55d398326f99059ff775485246999027b3197955

        address _stargateRouterAddress, //address of the stargate router on BNB - 0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8 as per https://stargateprotocol.gitbook.io/stargate/developers/contract-addresses/mainnet
        uint256 _stargateGasAmount, //unclear - but this can also be set later by the owner

        uint16 _srcPoolId, // 2 as per https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
        uint16 _dstPoolId, // 2 as per https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
        address _destStargateComposed, //address of the sgReciever deployed on ETH
        uint16 _dstChainId //101 - as per https://stargateprotocol.gitbook.io/stargate/developers/contract-addresses/mainnet
    ) Owned(_owner){
        ethAddress = _ethAddress;
        usdtAddress = _usdtAddress;

        stargateRouterAddress = _stargateRouterAddress;

        pancakeSwapRouterAddress = _pancakeSwapRouterAddress;
        pancakeSwapRouter = IUniswapV2Router02(pancakeSwapRouterAddress);

        stargateGasAmount = _stargateGasAmount;

        srcPoolId = _srcPoolId;
        dstPoolId = _dstPoolId;
        destStargateComposed = _destStargateComposed;
        dstChainId = _dstChainId;

        // Approve token allowances for router contracts
        TransferHelper.safeApprove(usdtAddress, stargateRouterAddress, type(uint256).max);
        TransferHelper.safeApprove(ethAddress, pancakeSwapRouterAddress, type(uint256).max);
    }

    modifier onlyWhenUnpaused {
        require(paused == false, "Contract is paused");
        _;
    }

    // owner function that sets the pool paramaters
    function setPoolParams(
        uint16 _srcPoolId, // 2 as per https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
        uint16 _dstPoolId, // 2 as per https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
        address _destStargateComposed, //address of the sgReciever deployed on ETH
        uint16 _dstChainId //101 - as per https://stargateprotocol.gitbook.io/stargate/developers/contract-addresses/mainnet
    ) public onlyOwner {
        srcPoolId = _srcPoolId;
        dstPoolId = _dstPoolId;
        destStargateComposed = _destStargateComposed;
        dstChainId = _dstChainId;
    }

    // owner function that sets the pause parameter
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    //owner function that sets the stargateGasAmount
    function setStargateGasAmount(uint256 _stargateGasAmount) public onlyOwner {
        stargateGasAmount = _stargateGasAmount;
    }

    function _getDeadline() internal view returns(uint256) {
        return block.timestamp + 300; //5 minutes
    }

    // mint_unsheth function that sends USDT to unshETH proxy contract to mint unshETH tokens
    function mint_unsheth_with_usdt(
        uint amount,                            // the amount of USDT
        uint min_amount_stargate,               // the minimum amount of USDT to receive on stargate,
        uint256 min_amount_unshethZap,          // the minimum amount of ETH to receive from the unshethZap
        uint256 leftover_amount,                // leftover eth that will get airdropped to the sgReceive contract
        uint256 unsheth_path                    // the path that the unsheth Zap will take to mint unshETH
    ) external payable onlyWhenUnpaused {
        // Mint unsheth with USDT
        _mint_unsheth_with_usdt(amount, min_amount_stargate, min_amount_unshethZap, leftover_amount, unsheth_path, msg.value);
    }

    // mint_unsheth function converts ETH to USDT and sends USDT to unshETH proxy contract to mint unshETH tokens
    function mint_unsheth_with_bnb(
        uint amount,                            // the amount of BNB to convert to USDT
        uint min_amount_pancake,                // the minimum amount of USDT to receive from pancake swap
        uint min_amount_stargate,               // the minimum amount of USDT to receive on stargate,
        uint256 min_amount_unshethZap,          // the minimum amount of ETH to receive from the unshethZap
        uint256 leftover_amount,                 // leftover eth that will get airdropped to the sgReceive contract
        uint256 unsheth_path                    // the path that the unsheth Zap will take to mint unshETH
    ) external payable onlyWhenUnpaused {
        require(msg.value > amount, "BNB amount must be greater than amount being used to buy usdt");
        require(unsheth_path <=5, 'there are only 6 unsheth paths');
        // Calculate the stargate fee
        uint256 stargateFee = msg.value - amount;
        // Create a path: BNB -> USDT
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = usdtAddress;
        // Swap BNB for USDT
        uint256[] memory amountsOut = pancakeSwapRouter.swapExactETHForTokens{value: amount}(
            min_amount_pancake, path, address(this), _getDeadline()
        );
        uint256 usdtBalance = amountsOut[1];
        // Mint unsheth with USDT
        _mint_unsheth_with_usdt(usdtBalance, min_amount_stargate, min_amount_unshethZap, leftover_amount, unsheth_path, stargateFee);
    }

    // mint_unsheth function converts ETH to USDT and sends USDT to unshETH proxy contract to mint unshETH tokens
    function mint_unsheth_with_eth(
        uint amount,                            // the amount of ETH to convert to USDT
        uint min_amount_pancake,                // the minimum amount of USDT to receive from pancake swap
        uint min_amount_stargate,               // the minimum amount of USDT to receive on stargate,
        uint256 min_amount_unshethZap,          // the minimum amount of ETH to receive from the unshethZap
        uint256 leftover_amount,                // leftover eth that will get airdropped to the sgReceive contract
        uint256 unsheth_path                    // the path that the unsheth Zap will take to mint unshETH
    ) external payable onlyWhenUnpaused {
        require(unsheth_path <=5, 'there are only 6 unsheth paths');
        // Transfer ETH from sender to the contract
        TransferHelper.safeTransferFrom(ethAddress, msg.sender, address(this), amount);
        // Create a path: ETH -> USDT
        address[] memory path = new address[](2);
        path[0] = ethAddress;
        path[1] = usdtAddress;
        //swap the eth for usdt
        uint256[] memory amounts = pancakeSwapRouter.swapExactTokensForTokens(
            amount, min_amount_pancake, path, address(this), _getDeadline()
        );
        uint256 usdtBalance = amounts[1];
        // Mint unsheth with USDT
        _mint_unsheth_with_usdt(usdtBalance, min_amount_stargate, min_amount_unshethZap, leftover_amount, unsheth_path, msg.value);
    }

    function _mint_unsheth_with_usdt(
        uint256 amount,
        uint256 min_amount_stargate,
        uint256 min_amount_unshethZap,
        uint256 leftover_amount,
        uint256 unsheth_path,
        uint256 bnbAmount
    ) internal {
        // Transfer USDT from sender to the contract
        TransferHelper.safeTransferFrom(usdtAddress, msg.sender, address(this), amount);
        // Encode payload data to send to destination contract, which it will handle with sgReceive()
        bytes memory data = abi.encode(msg.sender, min_amount_unshethZap, unsheth_path);
        // Send the USDT via the stargate router
        IStargateRouter(stargateRouterAddress).swap{value:bnbAmount}( //call estimateGasFees to get the msg.value
            dstChainId,                                               // the destination chain id - ETH
            srcPoolId,                                                // the source Stargate poolId - TODO pull from the docs (ensure this is hardcoded)
            dstPoolId,                                                // the destination Stargate poolId - TODO pull the docs (ensure this is hardcoded)
            payable(msg.sender),                                      // refund address. if msg.sender pays too much gas, return extra BNB
            amount,                                                   // total tokens to send to destination chain
            min_amount_stargate,                                      // min amount allowed out - TODO check on this
            IStargateRouter.lzTxObj(stargateGasAmount, leftover_amount, abi.encode(destStargateComposed)), // default lzTxObj
            abi.encodePacked(destStargateComposed),                   // destination address, the sgReceive() implementer
            data                                                      // bytes payload which sgReceive() will parse into an address that the unshETH will be sent too.
        );
    }
}