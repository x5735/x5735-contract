// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "./NewERC20.sol";
import "./Ownable.sol";
import "./AFIToken.sol";

contract AFIR is ERC20("AFI Token", "AFIR"), Ownable {
    uint256 private _cap = 188000000e18;
    uint256 private _totalLock;

    uint256 public startReleaseBlock;
    uint256 public endReleaseBlock;
    uint256 public manualMintLimit = 8000000e18;
    uint256 public manualMinted = 0;

    mapping(address => uint256) private _locks;
    mapping(address => uint256) private _lastUnlockBlock;

    mapping(address => bool) public minters;

    event Lock(address indexed to, uint256 value);

    constructor(uint256 _startReleaseBlock, uint256 _endReleaseBlock) public {
        require(_endReleaseBlock > _startReleaseBlock, "endReleaseBlock < startReleaseBlock");
        _setupDecimals(18);
        startReleaseBlock = _startReleaseBlock;
        endReleaseBlock = _endReleaseBlock;

        // maunalMint 250k for seeding liquidity
        minters[msg.sender] = true;
        manualMint(msg.sender, 250000e18);
    }

    /**
     * @dev Throws if called by any invalid minter.
     */
    modifier onlyMinter() {
        require(minters[msg.sender] == true, "caller is not minter");
        _;
    }

    function setMinter(address _minter, bool _value) public onlyOwner {
        minters[_minter] = _value;
    }

    function setReleaseBlock(uint256 _startReleaseBlock, uint256 _endReleaseBlock) public onlyOwner {
        require(_endReleaseBlock > _startReleaseBlock, "endReleaseBlock < startReleaseBlock");
        startReleaseBlock = _startReleaseBlock;
        endReleaseBlock = _endReleaseBlock;
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function unlockedSupply() public view returns (uint256) {
        return totalSupply().sub(totalLock());
    }

    function totalLock() public view returns (uint256) {
        return _totalLock;
    }

    function manualMint(address _to, uint256 _amount) public onlyMinter {
        require(manualMinted <= manualMintLimit, "mint limit exceeded");
        mint(_to, _amount);
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        require(totalSupply().add(_amount) <= cap(), "cap exceeded");
        _mint(_to, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyMinter {
        _burn(_account, _amount);
    }

    function totalBalanceOf(address _account) public view returns (uint256) {
        return _locks[_account].add(balanceOf(_account));
    }

    function lockOf(address _account) public view returns (uint256) {
        return _locks[_account];
    }

    function lastUnlockBlock(address _account) public view returns (uint256) {
        return _lastUnlockBlock[_account];
    }

    function lock(address _account, uint256 _amount) public onlyMinter {
        require(_account != address(0), "no lock to address(0)");
        require(_amount <= balanceOf(_account), "no lock over balance");

        _transfer(_account, address(this), _amount);

        _locks[_account] = _locks[_account].add(_amount);
        _totalLock = _totalLock.add(_amount);

        if (_lastUnlockBlock[_account] < startReleaseBlock) {
            _lastUnlockBlock[_account] = startReleaseBlock;
        }

        emit Lock(_account, _amount);
    }

    function canUnlockAmount(address _account) public view returns (uint256) {
        // When block number less than startReleaseBlock, no AFIRs can be unlocked
        if (block.number < startReleaseBlock) {
            return 0;
        }
        // When block number more than endReleaseBlock, all locked AFIRs can be unlocked
        else if (block.number >= endReleaseBlock) {
            return _locks[_account];
        }
        // When block number is more than startReleaseBlock but less than endReleaseBlock,
        // some AFIRs can be released
        else
        {
            uint256 releasedBlock = block.number.sub(_lastUnlockBlock[_account]);
            uint256 blockLeft = endReleaseBlock.sub(_lastUnlockBlock[_account]);
            return _locks[_account].mul(releasedBlock).div(blockLeft);
        }
    }

    function unlock() public {
        require(_locks[msg.sender] > 0, "no locked ALPACAs");

        uint256 amount = canUnlockAmount(msg.sender);

        _transfer(address(this), msg.sender, amount);
        _locks[msg.sender] = _locks[msg.sender].sub(amount);
        _lastUnlockBlock[msg.sender] = block.number;
        _totalLock = _totalLock.sub(amount);
    }

    /// @dev move AFIRs with its locked funds to another account
    function transferAll(address _to) public {
        _locks[_to] = _locks[_to].add(_locks[msg.sender]);

        if (_lastUnlockBlock[_to] < startReleaseBlock) {
            _lastUnlockBlock[_to] = startReleaseBlock;
        }

        if (_lastUnlockBlock[_to] < _lastUnlockBlock[msg.sender]) {
            _lastUnlockBlock[_to] = _lastUnlockBlock[msg.sender];
        }

        _locks[msg.sender] = 0;
        _lastUnlockBlock[msg.sender] = 0;

        _transfer(msg.sender, _to, balanceOf(msg.sender));
    }

}