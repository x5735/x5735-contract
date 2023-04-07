pragma solidity ^0.8.0;

import "./UpgradeabilityProxy.sol";

/**
 * @notice Wrapper around OpenZeppelin's UpgradeabilityProxy contract.
 * Permissions proxy upgrade logic to My Governance contract.
 * https://github.com/OpenZeppelin/openzeppelin-sdk/blob/release/2.8/packages/lib/contracts/upgradeability/UpgradeabilityProxy.sol
 * @dev Any logic contract that has a signature clash with this proxy contract will be unable to call those functions
 *      Please ensure logic contract functions do not share a signature with any functions defined in this file
 */
contract MyProxy is UpgradeabilityProxy {
    address private proxyAdmin;
    string private constant ERROR_ONLY_ADMIN = (
        "MyAdminUpgradeabilityProxy: Caller must be current proxy admin"
    );

    /**
     * @notice Sets admin address for future upgrades
     * @param _logic - address of underlying logic contract.
     *      Passed to UpgradeabilityProxy constructor.
     * @param _proxyAdmin - address of proxy admin
     *      Set to governance contract address for all non-governance contracts
     *      Governance is deployed and upgraded to have own address as admin
     * @param _data - data of function to be called on logic contract.
     *      Passed to UpgradeabilityProxy constructor.
     */
    constructor(
        address _logic,
        address _proxyAdmin,
        bytes memory _data
    )
    UpgradeabilityProxy(_logic, _data) public payable
    {
        proxyAdmin = _proxyAdmin;
    }

    function upgradeTo(address _newImplementation) external {
        require(msg.sender == proxyAdmin, ERROR_ONLY_ADMIN);
        _upgradeTo(_newImplementation);
    }

    function getMyProxyAdminAddress() external view returns (address) {
        return proxyAdmin;
    }

    function implementation() external view returns (address) {
        return _implementation();
    }

    function setMyProxyAdminAddress(address _adminAddress) external {
        require(msg.sender == proxyAdmin, ERROR_ONLY_ADMIN);
        proxyAdmin = _adminAddress;
    }
}