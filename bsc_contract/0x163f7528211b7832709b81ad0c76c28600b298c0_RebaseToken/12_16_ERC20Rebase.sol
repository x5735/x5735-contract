// SPDX-License-Identifier: MIT 
// Rebase Contracts

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
 
contract ERC20Rebase is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply; 
    string private _name;
    string private _symbol;


    mapping(address => uint256) private _gonBalances;
    mapping(address => bool) private _steady; 
    uint256 private _perFragment;
    uint256 public MAX_SUPPLY;
    uint256 private TOTAL_GONS;
    uint256 private constant MAX_UINT256 = ~uint256(0);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
 
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
 
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function _setTotalSupply(uint256 amount,bool isAdd) private{
        if(isAdd) { 
            if(_totalSupply == 0){
                TOTAL_GONS=MAX_UINT256 / 1e20 - ((MAX_UINT256 / 1e20) % amount);
                _perFragment = TOTAL_GONS / amount;
            }
            else{
                TOTAL_GONS+=amount*_perFragment;
            }
            _totalSupply += amount;
        }
        else{
            TOTAL_GONS-=amount*_perFragment;
            _totalSupply-=amount;
        } 
    }
    function _reBase(uint256 newTotalSupply) internal virtual{
        _totalSupply = newTotalSupply;
        _perFragment = TOTAL_GONS / _totalSupply;
    } 
    function balanceOf(address account) public view virtual override returns (uint256) {

        if(_steady[account] ||_totalSupply==0) return _balances[account]; 
        return _gonBalances[account] / _perFragment;
    } 
    function _setBalance(address account, uint256 amount) private{
        if(_steady[account])  _balances[account]=amount;
        else _gonBalances[account]= amount * _perFragment;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }


    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

  
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

   
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _setBalance(from,fromBalance - amount);  
            _setBalance(to, balanceOf(to) + amount); 
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        
        _setTotalSupply(amount,true);
        MAX_SUPPLY += amount*1400;
        unchecked {
            _setBalance(account,balanceOf(account)+ amount);
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _setBalance(account,accountBalance - amount); 
            _setTotalSupply(amount,false);
            MAX_SUPPLY -= amount*1400;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }
    function _setSteady(address account, bool isSteady) internal virtual{
        if( _steady[account] != isSteady ){
            if(isSteady) _balances[account]= balanceOf(account);
            if(!isSteady) _gonBalances[account]=_balances[account] * _perFragment;
            _steady[account]=isSteady;
        } 
    } 
    
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

   
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
   
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}