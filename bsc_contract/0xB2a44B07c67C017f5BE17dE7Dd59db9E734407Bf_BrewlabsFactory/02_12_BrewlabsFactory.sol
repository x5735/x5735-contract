pragma solidity =0.5.16;

import './interfaces/IBrewlabsFactory.sol';
import './interfaces/IBrewlabsFeeManager.sol';
import './BrewlabsPair.sol';

contract BrewlabsFactory is IBrewlabsFactory {
    address public feeTo;
    address public feeToSetter;
    address public feeManager;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB, bytes calldata feeDistribution) external returns (address pair) {
        require(tokenA != tokenB, 'Brewlabs: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Brewlabs: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Brewlabs: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(BrewlabsPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(feeManager != address(0), 'Brewlabs: FEE MANAGER NOT DECLARED');
        IBrewlabsFeeManager(feeManager).createPool(token0, token1, feeDistribution);
        // initialize pair
        IBrewlabsPair(pair).initialize(token0, token1, feeManager, feeDistribution);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Brewlabs: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Brewlabs: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeToSetter, 'Brewlabs: FORBIDDEN');
        feeManager = _feeManager;
    }
}