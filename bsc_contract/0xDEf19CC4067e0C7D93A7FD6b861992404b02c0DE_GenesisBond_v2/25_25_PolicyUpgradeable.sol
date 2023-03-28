// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "./interfaces/IPolicy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PolicyUpgradeable is IPolicy, Initializable {
    address internal _policy;
    address internal _newPolicy;

    event PolicyTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event PolicyPushed(
        address indexed newPolicy
    );

    function initPolicy(address owner) internal onlyInitializing {
        _policy = owner;
        emit PolicyTransferred(address(0), _policy);
    }

    function policy() public view override returns (address) {
        return _policy;
    }

    function newPolicy() public view returns (address) {
        return _newPolicy;
    }

    modifier onlyPolicy() {
        require(_policy == msg.sender, "Caller is not the owner");
        _;
    }

    function renouncePolicy() public virtual override onlyPolicy {
        emit PolicyTransferred(_policy, address(0));
        _policy = address(0);
        _newPolicy = address(0);
    }

    function pushPolicy(address newPolicy_) public virtual override onlyPolicy {
        require(
            newPolicy_ != address(0),
            "New owner is the zero address"
        );
        emit PolicyPushed(newPolicy_);
        _newPolicy = newPolicy_;
    }

    function pullPolicy() public virtual override {
        require(msg.sender == _newPolicy, "msg.sender is not new policy");
        emit PolicyTransferred(_policy, _newPolicy);
        _policy = _newPolicy;
    }
}