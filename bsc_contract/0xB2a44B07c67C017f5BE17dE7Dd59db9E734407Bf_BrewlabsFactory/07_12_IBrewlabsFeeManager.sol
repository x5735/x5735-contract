pragma solidity >=0.5.0;

interface IBrewlabsFeeManager {
    event Claimed(address indexed to, address indexed pair, uint amount0, uint amount1);

    function pendingLPRewards(address pair, address staker) external view returns(uint, uint);
    function createPool(address token0, address token1, bytes calldata feeDistribution) external;
    function claim(address pair) external;
    function claimAll(address[] calldata pairs) external;
    function lpMinted(address to, address token0, address token1, address pair) external;
    function lpBurned(address from, address token0, address token1, address pair) external;
    function lpTransferred(address from, address to, address token0, address token1, address pair) external;
    function notifyRewardAmount(address pair, address token, uint amount) external;
}