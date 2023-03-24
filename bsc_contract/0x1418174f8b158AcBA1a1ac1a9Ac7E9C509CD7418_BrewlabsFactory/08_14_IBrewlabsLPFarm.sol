pragma solidity >=0.5.0;

interface IBrewlabsLPFarm {
    event Claimed(address indexed to, uint amount0, uint amount1);

    function claim() external;
    function minted(address to) external;
    function burned(address from) external;
    function notifyRewardAmount(address token, uint amount) external;
}