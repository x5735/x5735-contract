// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswap.sol";

contract STINKY is ERC20, Ownable {
    mapping(address => uint256) public lastReceived; // Check if enough time has passed to apply taxes;
    mapping(address => bool) public taxExcluded; // Addresses that are excluded from taxes

    address public minter; // Address that can mint tokens
    address public dev; // Address that receives early tax
    uint8 public earlyTax = 20; // 20% tax on early transfers

    // This contract does not require a receive fn because it doesn't deal with ETH directly.

    /// @notice Modifier to check if the caller is the minter
    modifier isMinter() {
        require(msg.sender == minter, "STINKY: not minter");
        _;
    }

    constructor(
        address _minter,
        address _dev,
        address _stink
    ) ERC20("STINKY", "STINKY") {
        // 1 billion tokens initial supply
        _mint(msg.sender, 1_000_000_000 ether);
        minter = _minter;
        dev = _dev;
        taxExcluded[msg.sender] = true;
        taxExcluded[_minter] = true;
        taxExcluded[_dev] = true;

        // SET DEFAULT INIT PAIR
        IUniswapV2Router02 pancakeRouter = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        IUniswapV2Factory pancakeFactory = IUniswapV2Factory(
            pancakeRouter.factory()
        );
        address pair = pancakeFactory.createPair(
            address(this),
            pancakeRouter.WETH()
        );
        taxExcluded[pair] = true;
        pair = pancakeFactory.createPair(address(this), _stink);
        taxExcluded[pair] = true;
    }

    /// @notice Transfer function with early tax
    /// @param sender Address of the sender
    /// @param recipient Address of the recipient
    /// @param amount Amount of tokens to be transferred
    /// @dev If the recipient has received tokens in the last 72 hours, the sender will be charged a 20% tax
    ///     If the recipient has not received tokens in the last 72 hours, the sender will not be charged a tax
    ///     After transfer is made, the recipient tax timer is reset to 72 hours from current block timestamp
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (!taxExcluded[sender]) {
            if (lastReceived[sender] > block.timestamp) {
                uint256 tax = (amount * earlyTax) / 100;
                amount -= tax;
                super._transfer(sender, dev, tax);
            }
        }
        super._transfer(sender, recipient, amount);
        lastReceived[recipient] = block.timestamp + 72 hours;
    }

    /// @notice Mint function
    /// @param amount Amount of tokens to be minted
    /// @dev Only the minter can call this function
    function mint(uint256 amount) external isMinter {
        _mint(msg.sender, amount);
    }

    /// @notice Burn function
    /// @param amount Amount of tokens to be burned
    /// @dev Only the tokens of the caller can be burned
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burn FROM function
    /// @param account Address of the account to burn tokens from
    /// @param amount Amount of tokens to be burned
    /// @dev Only the tokens of the account can be burned
    function burnFrom(address account, uint256 amount) external {
        require(
            amount <= allowance(account, msg.sender),
            "STINKY: Not enough allowance"
        );
        uint256 decreasedAllowance = allowance(account, msg.sender) - amount;
        _approve(account, msg.sender, decreasedAllowance);
        _burn(account, amount);
    }

    /// @notice Set minter address
    /// @param _minter Address of the minter
    /// @dev Only the owner can call this function
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    /// @notice Set dev address
    /// @param _dev Address of the dev
    /// @dev Only the owner can call this function
    function setDev(address _dev) external onlyOwner {
        dev = _dev;
    }

    /// @notice Exclude address from TAX
    /// @param account Address to be excluded
    /// @dev Only the owner can call this function
    /// @dev PLEASE REMEMBER TO EXCLUDE PAIRS AND STAKING CONTRACTS FROM TAX
    function excludeFromTax(address account) external onlyOwner {
        taxExcluded[account] = true;
    }

    /// @notice Include address in TAX
    /// @param account Address to be included
    /// @dev Only the owner can call this function
    function includeInTax(address account) external onlyOwner {
        taxExcluded[account] = false;
    }

    ///@notice get tokens sent "mistakenly" to the contract
    ///@param _token Address of the token to be recovered
    function recoverToken(address _token) external {
        require(_token != address(this), "Cannot withdraw SELF");
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(IERC20(_token).transfer(dev, balance), "Transfer failed");
    }
}