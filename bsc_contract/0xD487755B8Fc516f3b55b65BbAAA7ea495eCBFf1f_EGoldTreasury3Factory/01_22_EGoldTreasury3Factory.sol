// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./EGoldTreasury3.sol";

contract EGoldTreasury3Factory is AccessControl {
    using SafeCast for *;
    using SafeMath for uint256;
    using Address for address;

    address public identity;
    address public minerReg;
    address public rank;
    address public master;
    uint256 public maxLevel;
    address public nft;


    event createInstance( address indexed _instance , address _identity , address _minerReg , address _rank ,  address _rate , address _master , uint256 _maxLevel , address _token , address _nft , address _DFA );

    constructor() AccessControl() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setup( address _identity , address _minerReg , address _rank , address _master , uint256 _maxLevel , address _nft ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        identity = _identity;
        minerReg = _minerReg;
        rank = _rank;
        master = _master;
        maxLevel = _maxLevel;
        nft = _nft;
    }

    //Factory Fx
    function create(
        address _token,
        address _rate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        EGoldTreasury3 instance = new EGoldTreasury3( identity , minerReg , rank , _rate , master , maxLevel , _token , nft , msg.sender );
        emit createInstance( address(instance) , identity , minerReg , rank , _rate , master , maxLevel , _token , nft , msg.sender );
    }
    //Factory Fx

}