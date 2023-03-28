// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./GenesisBond.sol";
import "./GenesisBondNft.sol";
import "./GenesisTreasury.sol";

contract GenesisFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
  struct BondParams {
    address principalToken;
    bool feeInPayout;
  }

  struct BondNftParams {
    string name;
    string symbol;
    string baseTokenURI;
  }

  struct TreasuryParams {
    address deployedTreasury;
    address payoutAddress;
    IERC20MetadataUpgradeable payoutToken;
  }

  struct BondInfo {
    address bond;
    address nft;
    address treasury;
  }

  // deployer => bond id => bond info
  mapping(address => mapping(uint => BondInfo)) public bondInfo;
  // deployer => bonds deployed
  mapping(address => uint) public bondCount;

  address public bondImplementation;
  address public bondNftImplementation;
  address public treasuryImplementation;
  address public feeReceiver;

  // Fees
  uint[] public tierCeilings;
  uint[] public fees;

  event Deploy(address bond, address nft, address treasury);
  event SetBondImplementation(address bondImplementation);
  event SetBondNftImplementation(address bondNftImplementation);
  event SetTreasuryImplementation(address treasuryImplementation);
  event SetFeeReceiver(address feeReceiver);
  event SetFees(uint[] _tierCeilings, uint[] _fees);

  function initialize(
    address _bondImplementation,
    address _bondNftImplementation,
    address _treasuryImplementation,
    address _feeReceiver,
    address _owner,
    uint[] memory _tierCeilings,
    uint[] memory _fees
  ) public initializer {
    __Ownable_init();

    setFeeReceiver(_feeReceiver);
    setBondImplementation(_bondImplementation);
    setBondNftImplementation(_bondNftImplementation);
    setTreasuryImplementation(_treasuryImplementation);
    setFees(_tierCeilings, _fees);

    transferOwnership(_owner);
  }

  function deploy(
    BondParams calldata _bondParams,
    BondNftParams calldata _bondNftParams,
    TreasuryParams calldata _treasuryParams
  ) public virtual {
    address treasuryProxy = _treasuryParams.deployedTreasury == address(0)
      ? _deployTreasuryProxy(_treasuryParams)
      : _treasuryParams.deployedTreasury;
    address nftProxy = _deployNftProxy(_bondNftParams);
    address bondProxy = _deployBondProxy(_bondParams, treasuryProxy, nftProxy);

    _registerBond(bondProxy, nftProxy, treasuryProxy);

    emit Deploy(bondProxy, nftProxy, treasuryProxy);
  }

  function _deployTreasuryProxy(TreasuryParams calldata _treasuryParams) internal returns (address) {
    ERC1967Proxy treasuryProxy = _deployProxy(
      treasuryImplementation,
      abi.encodeWithSelector(
        GenesisTreasury(address(0)).initialize.selector,
        msg.sender,
        _treasuryParams.payoutToken,
        _treasuryParams.payoutAddress,
        owner()
      )
    );

    return address(treasuryProxy);
  }

  function _deployNftProxy(BondNftParams calldata _bondNftParams) internal returns (address) {
    ERC1967Proxy nftProxy = _deployProxy(
      bondNftImplementation,
      abi.encodeWithSelector(
        GenesisBondNft(address(0)).initialize.selector,
        _bondNftParams.name,
        _bondNftParams.symbol,
        _bondNftParams.baseTokenURI,
        address(this),
        msg.sender,
        owner()
      )
    );

    return address(nftProxy);
  }

  function _deployBondProxy(
    BondParams calldata _bondParams,
    address _treasuryProxy,
    address _nftProxy
  ) internal returns (address) {
    ERC1967Proxy bondProxy = _deployProxy(
      bondImplementation,
      abi.encodeWithSelector(
        GenesisBond(address(0)).initialize.selector,
        [
          _treasuryProxy,
          _bondParams.principalToken,
          feeReceiver,
          _nftProxy,
          msg.sender
        ],
        tierCeilings,
        fees,
        false,
        owner()
      )
    );

    GenesisBondNft(_nftProxy).addMinter(address(bondProxy));

    return address(bondProxy);
  }

  function _deployProxy(
    address _implementationAddress,
    bytes memory _params
  ) internal returns (ERC1967Proxy) {
    return new ERC1967Proxy(_implementationAddress, _params);
  }

  function _registerBond(address bondProxy, address nftProxy, address treasuryProxy) internal {
    bondInfo[msg.sender][bondCount[msg.sender]] = BondInfo({
      bond: bondProxy,
      nft: nftProxy,
      treasury: treasuryProxy
    });

    bondCount[msg.sender] += 1;
  }

  function setBondImplementation(address _bondImplementation) public onlyOwner {
    bondImplementation = _bondImplementation;

    emit SetBondImplementation(bondImplementation);
  }

  function setBondNftImplementation(address _bondNftImplementation) public onlyOwner {
    bondNftImplementation = _bondNftImplementation;

    emit SetBondNftImplementation(bondNftImplementation);
  }

  function setTreasuryImplementation(address _treasuryImplementation) public onlyOwner {
    treasuryImplementation = _treasuryImplementation;

    emit SetTreasuryImplementation(treasuryImplementation);
  }

  function setFeeReceiver(address _feeReceiver) public onlyOwner {
    feeReceiver = _feeReceiver;

    emit SetFeeReceiver(feeReceiver);
  }

  function setFees(uint[] memory _tierCeilings, uint[] memory _fees) public onlyOwner {
    tierCeilings = _tierCeilings;
    fees = _fees;

    emit SetFees(tierCeilings, fees);
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}
}