// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract TokenDeploy is ERC20, Ownable {
    using SafeMath for uint256;
    ERC20 public tokenReceive;
    event TokenLocked(address indexed account, uint256 amount);
    event TokenUnlocked(address indexed account, uint256 amount);
    event TransfersEnabled(bool newStatus);
    event AuthorizeRoleAssigned(address authorizeRole);            
    mapping(address => uint256) public lockedBalanceOf;
    mapping(address => uint256) public userLockTimeLastUpdated;    
    mapping(address => uint256) public countLockTransOfUser;
    address public authorizeRole;
    bool public transfersEnabled;
    uint256 public oneDollar = 1000000000000000000; // 1 Dollar
    uint256 public maxLimit = 1000000 * 10 ** 18;
    uint256 public minLimit = 60 * 10 ** 18;
    uint256 public percentLimit;
    uint256 public secondOfDay;
    constructor(string memory name_, string memory symbol_) ERC20(name_='demoTk', symbol_='DMT') {
        _mint(msg.sender, 72000000 * 10 ** decimals());
        secondOfDay = 1; //24*60*60;
        percentLimit = (10**18)*(3/100);
        tokenReceive = ERC20(0x55d398326f99059fF775485246999027B3197955);
    }
    modifier transfersAllowed {
        require(transfersEnabled, "Transfers not available");
        _;
    }
    modifier onlyAuthorized {
        require(_msgSender() == owner() || _msgSender() == authorizeRole, "Not authorized");
        _;
    }
    function getBalanceOfReceive(address _address) public view returns(uint256) {
        uint256 amount = tokenReceive.balanceOf(_address);
        return amount;
    }
    function currentBalanceBNB(address _contractAddress) public view returns (uint) {
        return address(_contractAddress).balance;
    }
    function setContractReceive(address _contractAddress) public onlyAuthorized returns (bool) {
        tokenReceive = ERC20(_contractAddress);
        return true;
    }
    function setPercentLimit(uint256 _value) public onlyAuthorized returns (bool) {
        require(_value > 0, "Input value do not match");
        percentLimit = _value;
        return true;
    }
    function unlockPercentOfUser(address _wallet) public onlyAuthorized {
        uint256 percentReceive = lockedBalanceOf[_wallet].mul(3).div(100);
        require(lockedBalanceOf[_wallet] > 0 && lockedBalanceOf[_wallet] >= percentReceive, "Not enough unlocked token balance");
        if(block.timestamp - userLockTimeLastUpdated[_wallet] >= secondOfDay) {
            if (lockedBalanceOf[_wallet] > 0 && lockedBalanceOf[_wallet] <= percentLimit) {
                lockedBalanceOf[_wallet] = lockedBalanceOf[_wallet].sub(lockedBalanceOf[_wallet]);
                userLockTimeLastUpdated[_wallet] = userLockTimeLastUpdated[_wallet] = block.timestamp;
                countLockTransOfUser[_wallet] = countLockTransOfUser[_wallet].add(1);
                emit TokenUnlocked(_wallet, lockedBalanceOf[_wallet]);
            } else if (percentReceive > 0 && lockedBalanceOf[_wallet] > 0 && lockedBalanceOf[_wallet] >= percentReceive) {
                lockedBalanceOf[_wallet] = lockedBalanceOf[_wallet].sub(percentReceive);
                userLockTimeLastUpdated[_wallet] = userLockTimeLastUpdated[_wallet] = block.timestamp;
                countLockTransOfUser[_wallet] = countLockTransOfUser[_wallet].add(1);
                emit TokenUnlocked(_wallet, percentReceive);
            }
        }
    }
    function unlockPercentDailys(address[] memory _wallet) public onlyAuthorized {
        require(_wallet.length > 0, "Input lengths do not match");
        for (uint256 i = 0; i < _wallet.length; i++) {
            uint256 percentReceive = lockedBalanceOf[_wallet[i]].mul(3).div(100);
            if (lockedBalanceOf[_wallet[i]] > 0 && lockedBalanceOf[_wallet[i]] <= percentLimit) {
                lockedBalanceOf[_wallet[i]] = lockedBalanceOf[_wallet[i]].sub(lockedBalanceOf[_wallet[i]]);
                userLockTimeLastUpdated[_wallet[i]] = userLockTimeLastUpdated[_wallet[i]] = block.timestamp;
                countLockTransOfUser[_wallet[i]] = countLockTransOfUser[_wallet[i]].add(1);
                emit TokenUnlocked(_wallet[i], lockedBalanceOf[_wallet[i]]);
            } else if (percentReceive > 0 && lockedBalanceOf[_wallet[i]] > 0 && lockedBalanceOf[_wallet[i]] >= percentReceive) {
                lockedBalanceOf[_wallet[i]] = lockedBalanceOf[_wallet[i]].sub(percentReceive);
                userLockTimeLastUpdated[_wallet[i]] = userLockTimeLastUpdated[_wallet[i]] = block.timestamp;
                countLockTransOfUser[_wallet[i]] = countLockTransOfUser[_wallet[i]].add(1);
                emit TokenUnlocked(_wallet[i], percentReceive);
            }            
        }
    }
    function timetemp() public view returns (uint256) {
        return block.timestamp;
    }
    function unlockedBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account).sub(lockedBalanceOf[account]);
    }    
    function lockTransfer(address account, uint256 amount) public onlyAuthorized returns (bool) {
        require(amount > 0 && unlockedBalanceOf(account) >= amount, "Not enough unlocked tokens");
        lockedBalanceOf[account] = lockedBalanceOf[account].add(amount);
        emit TokenLocked(account, amount);
        return true;
    }
    function unlockTransfers(address[] memory accounts, uint256 amount) public onlyAuthorized returns (bool) {
        require(amount > 0 && accounts.length > 0, "Input lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            if (lockedBalanceOf[accounts[i]] >= amount) {
                lockedBalanceOf[accounts[i]] = lockedBalanceOf[accounts[i]].sub(amount);
                emit TokenUnlocked(accounts[i], amount);
            }
        }
        return true;
    }
    function withdrawOfUser(address accounts) public onlyAuthorized returns (bool) {
        uint256 amount = lockedBalanceOf[accounts];
        if (lockedBalanceOf[accounts] > 0) {
            lockedBalanceOf[accounts] = lockedBalanceOf[accounts].sub(amount);
            emit TokenUnlocked(accounts, amount);
        }
        return true;
    }
    function withdraws(address[] memory accounts) public onlyAuthorized returns (bool) {
        require(accounts.length > 0, "Input lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 amount = lockedBalanceOf[accounts[i]];
            if (lockedBalanceOf[accounts[i]] > 0) {
                lockedBalanceOf[accounts[i]] = lockedBalanceOf[accounts[i]].sub(amount);
                emit TokenUnlocked(accounts[i], amount);
            }
        }
        return true;
    }
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(unlockedBalanceOf(_msgSender()) >= amount, "Not enough unlocked token balance");
        return super.transfer(to, amount);
    }
    function transfers(
        address[] memory recipients,
        uint256[] memory values
    ) public transfersAllowed returns (bool) {
        require(recipients.length == values.length, "Input lengths do not match");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(values[i] > 0 && unlockedBalanceOf(recipients[i]) >= values[i], "Not enough unlocked token balance");
            transfer(recipients[i], values[i]);
        }
        return true;
    }
    function transferLock(address recipient, uint256 amount) public onlyAuthorized returns (bool) {
        require(amount > 0 && unlockedBalanceOf(_msgSender()) >= amount, "Not enough unlocked token balance");
        super.transfer(recipient, amount);
        lockedBalanceOf[recipient] = lockedBalanceOf[recipient].add(amount);
        emit TokenLocked(recipient, amount);
        return true;
    }
    function transferFrom(address from,
        address to,
        uint256 amount) public returns (bool) {
        require(amount > 0 && unlockedBalanceOf(from) >= amount, "Not enough unlocked token balance of sender");
        return transferFrom(from, to, amount);
    }
    function setSecondOfDay(uint256 _value) public onlyAuthorized {
        secondOfDay = _value;
    }
}