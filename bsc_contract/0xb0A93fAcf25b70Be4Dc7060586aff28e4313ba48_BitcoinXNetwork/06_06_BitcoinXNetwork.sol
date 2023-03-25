// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract BitcoinXNetwork is ERC20, ERC20Burnable {
    address public owner;    
    uint256 public maxSupply;
    mapping(address => bool) private _isBlacklisted;
        
    event UserBlacklisted(address indexed addr);
    event UserUnBlacklisted(address indexed addr);
    event OwnershipTransferred(address indexed _owner, address indexed _address);
    error SenderBlacklisted(address addr);
    error RecipientBlacklisted(address addr);
    
    constructor() ERC20('BitcoinX Network', 'BTCX'){
        owner = msg.sender;
        mint(msg.sender, 200000000000000 * 10**18);
        maxSupply = 200000000000000 * 10**18;
    }

    function mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        validateTransfer(msg.sender, to)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override
        validateTransfer(from, to)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    function addBlackList(address addr) external onlyOwner { 
        _isBlacklisted[addr] = true;
        emit UserBlacklisted(addr);
    }

    function removeBlacklist(address addr) external onlyOwner {
        _isBlacklisted[addr] = false;
        emit UserUnBlacklisted(addr);
    }

    function isBlacklistUser(address addr) public view returns (bool) {
        return _isBlacklisted[addr];
    }

    function transferOwnership(address _address) public onlyOwner {
        require(_address != address(0), "Invalid Address");
        owner = _address;
        emit OwnershipTransferred(owner, _address);     
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner can call this function");
        _;
    }

    modifier validateTransfer(address sender, address recipient) {
        if (_isBlacklisted[sender]) {
             revert SenderBlacklisted(sender);
        }
        if (_isBlacklisted[recipient]) {
            revert RecipientBlacklisted(recipient);
        }
        _;
    }

}