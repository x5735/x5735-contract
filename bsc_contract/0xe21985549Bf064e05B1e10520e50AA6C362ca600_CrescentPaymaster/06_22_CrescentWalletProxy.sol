// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "./CrescentWalletController.sol";

contract CrescentWalletProxy is Proxy, ERC1967Upgrade {

    // This is the keccak-256 hash of "eip4337.proxy.auto_update" subtracted by 1
    bytes32 private constant _AUTO_UPDATE_SLOT = 0xa5a17d1ea6249d0fb1885c3256371b6d5f681c9e9d78ab6541528b3876ccbf4c;

    // This is the keccak-256 hash of "eip4337.proxy.address_controller" subtracted by 1
    bytes32 private constant _ADDRESS_CONTROLLER_SLOT = 0x2374cd50a5aadd10053041ecb594cc361d7af780edf0e72f6583c2ea6919be93;

    constructor(address entryPoint, address controller, address dkim, address dkimVerifier) {
        StorageSlot.getBooleanSlot(_AUTO_UPDATE_SLOT).value = false;

        _changeAdmin(entryPoint);

        setController(controller);

        address implementation = getControlledImplementation();

        _upgradeTo(implementation);

        (bool success, bytes memory data) = implementation.delegatecall(abi.encodeWithSignature("initialize(address,address,address)", entryPoint, dkim, dkimVerifier));
        (data);
        require(success);
    }


    function upgradeDelegate(address newDelegateAddress) public {
        require(msg.sender == _getAdmin());
        _upgradeTo(newDelegateAddress);
    }

    function setAutoUpdateImplementation(bool value) public {
        require(msg.sender == _getAdmin());
        StorageSlot.getBooleanSlot(_AUTO_UPDATE_SLOT).value = value;
    }

    function getAutoUpdateImplementation() public view returns(bool) {
        return StorageSlot.getBooleanSlot(_AUTO_UPDATE_SLOT).value;
    }

    function setController(address controller) private {
        StorageSlot.getAddressSlot(_ADDRESS_CONTROLLER_SLOT).value = controller;
    }

    function getControlledImplementation() private view returns (address) {
        address controller = StorageSlot.getAddressSlot(_ADDRESS_CONTROLLER_SLOT).value;
        return CrescentWalletController(controller).getImplementation();
    }

    function getImplementation() public view returns (address) {
        return _implementation();
    }

    /**
    * @dev Returns the current implementation address.
    */
    function _implementation() internal view virtual override returns (address impl) {
        if (getAutoUpdateImplementation()) {
            impl = getControlledImplementation();
        } else {
            impl = ERC1967Upgrade._getImplementation();
        }
    }

}