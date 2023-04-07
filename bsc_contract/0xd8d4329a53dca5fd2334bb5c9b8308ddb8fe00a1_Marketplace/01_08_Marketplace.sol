// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface Token {
  function transfer(address _to, uint256 _amount) external view returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function transferFrom(address from, address to, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);
}

contract Marketplace is Initializable, OwnableUpgradeable, IERC721ReceiverUpgradeable {
  address payable private TEAM_WALLET;
  event Minted(uint256 _nftId);
  event Purchased(uint256 _nftId, string _callbackId);
  event ErrorPurchased(uint256 _nftId, string _callbackId);
  event ErrorAlreadyPurchased(uint256 _nftId, string _callbackId);
  Token internal token;

  struct AssetDetails {
    uint256 price;
    bool isSold;
    bool isMinted;
  }

  mapping(uint256 => AssetDetails) private _nftDetails;

  address private NFT_ERC721_CONTRACT;

  IUniswapV2Router02 private uniswapV2Router;
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() initializer public {
    __Ownable_init();
  }

  function setUniswapV2Router(address _address) external onlyOwner {
    uniswapV2Router = IUniswapV2Router02(_address);
  }

  function approve(address spender, uint256 amount) public onlyOwner {
    token.approve(spender, amount);
  }

  function setTeamWallet(address payable _teamWallet) external onlyOwner {
    TEAM_WALLET = _teamWallet;
  }

  function getTeamWallet() external view returns(address payable) {
    return TEAM_WALLET;
  }

  function setNFTERC721Contract(address _address) external onlyOwner {
    NFT_ERC721_CONTRACT = _address;
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    return IERC721ReceiverUpgradeable.onERC721Received.selector;
  }

  function getAssetDetailsOf(uint256 _nftId) external view returns(AssetDetails memory) {
    return _nftDetails[_nftId];
  }

  function setTokenAddress(address _token) external onlyOwner {
    token = Token(_token);
  }

  function getTokenAddress() external view returns(Token) {
    return token;
  }

  /*
    * _royaltyAmount : 100 = 1%. 5 000 = 50%.
  */
  function mint(
    uint256 _id,
    uint256 _sellPrice,
    uint96 _royaltyAmount,
    address _feesReceiverAddress
  ) public onlyOwner {
    require(
      NFT_ERC721_CONTRACT != address(0),
      "Sorry, there is an error on external contract address.")
    ;
    
    (bool isSuccess, bytes memory data) = NFT_ERC721_CONTRACT.call(
      abi.encodeWithSignature("safeMintNFT(uint96,uint256,uint256,address)", _royaltyAmount, _id, _sellPrice, _feesReceiverAddress)
    );

    if (isSuccess) {
      uint256 nftId = abi.decode(data, (uint256));
      _nftDetails[nftId] = AssetDetails(_sellPrice, false, true);

      emit Minted(nftId);
    } else {
      revert("Error on mint");
    }
  }

  function ownerOf(uint256 _nftId) internal returns(address) {
    (, bytes memory dataOwner) = NFT_ERC721_CONTRACT.call(
      abi.encodeWithSignature("ownerOf(uint256)", _nftId)
    );

    return abi.decode(dataOwner, (address));
  }

  /*function getBnbEyecPairAddress() external view returns(address) {
    address eyec = address(token);
    address pairAddress = IPancakeFactory.getPair(eyec);
  }*/

  function purchaseWithBNB(uint256 _nftId, string memory _callbackId) external payable purchaseVerifications(_nftId, msg.sender, _callbackId) {
    address buyer = msg.sender;
    address payable seller = payable(address(this));
    uint256 sellPrice = _nftDetails[_nftId].price;

    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();
    path[1] = address(token);
    uniswapV2Router.swapETHForExactTokens{value: msg.value}(sellPrice, path, this.getTeamWallet(), block.timestamp);

    (bool isSuccess,) = NFT_ERC721_CONTRACT.call(
      abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", seller, buyer, _nftId)
    );

    afterNFTTransfer(_nftId, _callbackId, isSuccess);
  }

  function addLiquididty(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to) external onlyOwner {
    uniswapV2Router.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, block.timestamp);
  }

  function WETH() external view returns(address) {
    return uniswapV2Router.WETH();
  }

  function buy(uint256 _nftId, string memory _callbackId) external purchaseVerifications(_nftId, msg.sender, _callbackId) {
    address buyer = msg.sender;
    address payable seller = payable(address(this));
    uint256 sellPrice = _nftDetails[_nftId].price;

    require(token.allowance(buyer, address(this)) >= sellPrice, "ERC20: transfer amount exceeds allowance.");

    uint256 price = sellPrice;

    // Deposit EYEC funds on the ERC20 contract.
    token.transferFrom(buyer, this.getTeamWallet(), price);

    (bool isSuccess,) = NFT_ERC721_CONTRACT.call(
      abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", seller, buyer, _nftId)
    );

    afterNFTTransfer(_nftId, _callbackId, isSuccess);
  }

  function afterNFTTransfer(uint256 _nftId, string memory _callbackId, bool _isSuccess) internal {
    if (_isSuccess) {
      _nftDetails[_nftId].isSold = true;
      emit Purchased(_nftId, _callbackId);
    } else {
      emit ErrorPurchased(_nftId, _callbackId);
      revert("Error on buy");
    }
  }

  modifier purchaseVerifications(uint256 _nftId, address buyer, string memory _callbackId) {
    address payable seller = payable(address(this));
    uint256 sellPrice = _nftDetails[_nftId].price;

    require(seller != buyer, "You cannot buy your own NFT.");

    if (_nftDetails[_nftId].isSold) {
      emit ErrorAlreadyPurchased(_nftId, _callbackId);
      revert("Sorry, this NFT has been already sold.");
    }

    _;
  }

  receive() payable external {
    (bool success,) = tx.origin.call{value:msg.value}(new bytes(0));
    require(success, 'MarketPlace: ETH_TRANSFER_FAILED');
  }
}