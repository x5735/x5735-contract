// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '../interfaces/IUnoAccessManager.sol'; 

interface IUnoAutoStrategyFactory{
    struct PoolInfo {
        address assetRouter;
        address pool;
    }

    event AutoStrategyDeployed(address indexed autoStrategyAddress);
    event AssetRouterApproved(address indexed assetRouter);
    event AssetRouterRevoked(address indexed assetRouter);

    function assetRouterApproved(address) external view returns (bool);
    function accessManager() external view returns (IUnoAccessManager);
    function autoStrategyBeacon() external view returns (address);
    function autoStrategies(uint256) external view returns (address);

    function createStrategy(PoolInfo[] calldata poolInfos, string calldata name, string calldata symbol) external returns (address);
    function approveAssetRouter(address _assetRouter) external;
    function revokeAssetRouter(address _assetRouter) external;

    function upgradeStrategies(address newImplementation) external;
    function autoStrategiesLength() external view returns (uint256);

    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}