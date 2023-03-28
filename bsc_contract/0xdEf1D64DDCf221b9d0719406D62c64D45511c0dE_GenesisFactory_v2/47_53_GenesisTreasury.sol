// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./PolicyUpgradeable.sol";

contract GenesisTreasury is Initializable, PolicyUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /* ======== DEPENDENCIES ======== */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ======== STATE VARIABLES ======== */

    IERC20MetadataUpgradeable public payoutToken;

    address public payoutAddress;

    mapping(address => bool) public bondContract;

    /* ======== EVENTS ======== */

    event BondContractToggled(address indexed bondContract, bool approved);
    event Withdraw(address indexed token, address indexed destination, uint256 amount);

    /* ======== CONSTRUCTOR ======== */

    function initialize(
      address _owner,
      IERC20MetadataUpgradeable _payoutToken,
      address _payoutAddress,
      address _proxyOwner
    ) public initializer {
        __Ownable_init();
        transferOwnership(_proxyOwner);

        require(address(_payoutToken) != address(0), "Payout token cannot address zero");
        payoutToken = _payoutToken;
        require(_owner!= address(0), "initialOwner can't address 0");
        initPolicy(_owner);
        require(_payoutAddress != address(0), "payoutAddress can't address 0");
        payoutAddress = _payoutAddress;
    }

    /* ======== bond CONTRACT FUNCTION ======== */

    /**
     *  @notice deposit principal token and recieve back payout token
     *  @param _principalTokenAddress address
     *  @param _amountPrincipalToken uint
     *  @param _amountPayoutToken uint
     */
    function deposit(
        IERC20Upgradeable _principalTokenAddress,
        uint256 _amountPrincipalToken,
        uint256 _amountPayoutToken
    ) external {
        require(bondContract[msg.sender], "msg.sender not bond contract");
        _principalTokenAddress.safeTransferFrom(
            msg.sender,
            payoutAddress,
            _amountPrincipalToken
        );
        IERC20Upgradeable(payoutToken).safeTransfer(msg.sender, _amountPayoutToken);
    }

    /* ======== VIEW FUNCTION ======== */

    /**
     *   @notice returns payout token valuation of principal
     *   @param _principalTokenAddress address
     *   @param _amount uint
     *   @return value_ uint
     */
    function valueOfToken(IERC20MetadataUpgradeable _principalTokenAddress, uint256 _amount)
        external
        view
        returns (uint256 value_)
    {
        // convert amount to match payout token decimals
        value_ = (_amount * 10 ** payoutToken.decimals()) / 
        (10 ** _principalTokenAddress.decimals());
    }

    /* ======== POLICY FUNCTIONS ======== */

    /**
     *  @notice policy can withdraw ERC20 token to desired address
     *  @param _token address
     *  @param _destination address
     *  @param _amount uint
     */
    function withdraw(
        address _token,
        address _destination,
        uint256 _amount
    ) external onlyPolicy {
        IERC20Upgradeable(_token).safeTransfer(_destination, _amount);

        emit Withdraw(_token, _destination, _amount);
    }

    /**
        @notice toggle bond contract
        @param _bondContract address
     */
    function toggleBondContract(address _bondContract) external onlyPolicy {
        bondContract[_bondContract] = !bondContract[_bondContract];
        emit BondContractToggled(_bondContract, bondContract[_bondContract]);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}