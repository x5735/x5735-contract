// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

contract CryptoLoots is ERC20, Ownable {
    address public constant BURN_WALLET =
        0x000000000000000000000000000000000000dEaD;

    uint256 public constant FEE_PERCENT = 200;
    uint256 public constant FEE_DECIMAL = 2;

    mapping(address => bool) private __pairs;
    mapping(address => bool) private __is_taxless;

    bool private __is_in_fee_transfer;

    event TaxLess(address indexed wallet, bool value);
    event AddPair(address indexed router, address indexed pair);

    constructor(
        address _router,
        address _tokenB
    ) ERC20("CryptoLoots Token", "CLOOT") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        addPair(_router, _uniswapV2Router.WETH());
        addPair(_router, _tokenB);

        __is_taxless[msg.sender] = true;
        __is_taxless[address(this)] = true;
        __is_taxless[address(0)] = true;

        _mint(msg.sender, 20_000_000 ether);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._afterTokenTransfer(from, to, amount);

        if (!__is_in_fee_transfer) {
            uint256 fees_collected;
            if (!__is_taxless[from] && !__is_taxless[to] && __pairs[to]) {
                fees_collected += calculateFee(amount);
            }

            if (fees_collected > 0) {
                __is_in_fee_transfer = true;
                _transfer(to, BURN_WALLET, fees_collected);
                __is_in_fee_transfer = false;
            }
        }
    }

    function calculateFee(uint256 _amount) internal pure returns (uint256 fee) {
        return (_amount * FEE_PERCENT) / (10 ** (FEE_DECIMAL + 2));
    }

    function setIsTaxless(address _address, bool value) external onlyOwner {
        __is_taxless[_address] = value;
        emit TaxLess(_address, value);
    }

    function addPair(address _router, address _token) public onlyOwner {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        address pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _token
        );
        __pairs[pair] = true;
        emit AddPair(_router, pair);
    }

    function isTaxLess(
        address _address
    ) external view returns (bool is_tax_less) {
        return __is_taxless[_address];
    }

    function isPair(address _pair) external view returns (bool is_pair) {
        return __pairs[_pair];
    }
}