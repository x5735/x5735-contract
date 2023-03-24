import "./ReentrancyGuardUpgradeable.sol";
import "./Math.sol";
import "./SafeMath.sol";
import "./SafeERC20Upgradeable.sol";
import "./IERC20Upgradeable.sol";
import "./ERC721Enumerable.sol";
import "./IERC721.sol";
import "./GovernanceUpgradeable.sol";
import "./IERC20Upgradeable.sol";

// NFT
import "./InterfaceNFT.sol";
import "./InterfaceFactory.sol";

contract Factory is Initializable, GovernanceUpgradeable  {

    using Address for address;
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;



    uint256 private _maxGegoV1Id = 0;
    uint256 public _gegoId = _maxGegoV1Id;
    uint256 public coinageLimit = 50;
    uint256 public saleValue = 50 * 10**18;

    address public paymentCurrency = 0x55d398326f99059fF775485246999027B3197955;
    address public receivingAddress = 0xE8fF0167494B02E919c7B8339B986d19da7f9412;

    InterfaceNFT public _InterfaceNFT;

    event NFTReceived(address operator, address from, uint256 tokenId, bytes data);
    event NFTAddressChange(address indexed oldAddress, address indexed newAddress); 

    mapping(uint256 => MintData) public _MintData;
    mapping(uint256 => InterfaceNFT.Gego) public _gegoes;

    struct MintData{
        address owner;
        uint256 ruleId;
        uint256 amount;
    }


    function initialize(address _NFT) public initializer  {
        __Ownable_init();
        _InterfaceNFT = InterfaceNFT(_NFT);
    }


    function mint(uint256 tokenId) public  returns(bool) {
        _gegoId++;
        require(_gegoId <= coinageLimit, "Mint limit reached");
        MintData storage mintData   = _MintData[tokenId];

        IERC20Upgradeable mintIErc20 = IERC20Upgradeable(paymentCurrency);
        mintIErc20.transferFrom(_msgSender(), address(this), saleValue);
        mintIErc20.transfer(receivingAddress, saleValue);

        mintData.owner = _msgSender();
        mintData.ruleId = tokenId;
        mintData.amount = 10000;

        InterfaceNFT.Gego memory gego;

        uint256 gegoId = tokenId;


        gego.author = msg.sender;
        gego.id = gegoId;
        gego.amount = mintData.amount * 1e18;
        gego.grade = 4;
        gego.quality = 9890;
        gego.createdTime = gego.createdTime > 0 ? gego.createdTime : block.timestamp;
        _gegoes[gegoId] = gego;

        _InterfaceNFT.safeMint(msg.sender,tokenId);
        return true;
    }

    function manualMint(uint256 tokenId, address to) public onlyGovernance returns(bool) {
        _gegoId++;
        require(_gegoId <= coinageLimit, "Mint limit reached");
        MintData storage mintData   = _MintData[tokenId];

        mintData.owner = _msgSender();
        mintData.ruleId = tokenId;
        mintData.amount = 10000;

        InterfaceNFT.Gego memory gego;

        uint256 gegoId = tokenId;


        gego.author = to;
        gego.id = gegoId;
        gego.amount = mintData.amount * 1e18;
        gego.grade = 4;
        gego.quality = 9890;
        gego.createdTime = gego.createdTime > 0 ? gego.createdTime : block.timestamp;
        _gegoes[gegoId] = gego;

        _InterfaceNFT.safeMint(to,tokenId);
        return true;
    }

    function setLimitMint(uint256 _coinageLimit) public onlyGovernance {
        coinageLimit = _coinageLimit;
    }

    function setTokenURI(uint256 tokenId, string memory defineURI) public virtual  onlyGovernance {
        _InterfaceNFT.setTokenURI(tokenId, defineURI);
    }
    function burn(uint256 tokenId) public returns(bool){
        MintData storage nft   = _MintData[tokenId];

        nft.owner = address(0);
   
        _InterfaceNFT.safeTransferFrom(msg.sender, address(this), tokenId);
        _InterfaceNFT.burn(tokenId);
        return true;
    }
    function transferNFT(address from, address to, uint256 tokenId) public returns(bool) {
        MintData storage nft   = _MintData[tokenId];

        nft.owner = to;

        _InterfaceNFT.safeTransferFrom(from, to, tokenId);
  
        return true;
    }
    function setContractNFT(address oldAddress, address newAddress) public onlyGovernance {
        require(newAddress != oldAddress && oldAddress == address(_InterfaceNFT), "The new NFT address cannot be the same as the old one" );
        _InterfaceNFT = InterfaceNFT(newAddress);
        emit NFTAddressChange(oldAddress, newAddress);
    }
    function getGego(uint256 tokenId) external  view returns 
            (        
            uint256 grade,
            uint256 quality,
            uint256 amount,
            uint256 resBaseId,
            uint256 tLevel,
            uint256 ruleId,
            uint256 nftType,
            address author,
            address erc20,
            uint256 createdTime,
            uint256 blockNum,
            uint256 lockedDays) {
         InterfaceNFT.Gego storage gego = _gegoes[tokenId];
         require(gego.id > 0, "gego not exist");
         ruleId = gego.id;
         author = gego.author;
         amount = gego.amount;
         createdTime = gego.createdTime;
         lockedDays = gego.lockedDays;
    }
    function getAmount(uint256 tokenId) external view  returns(uint256, uint256, uint256) {
        InterfaceNFT.Gego storage gego = _gegoes[tokenId];
        return (gego.grade, gego.quality, gego.amount);
    }
    function getGegoStruct(uint256 tokenId)
        external  view
        returns (InterfaceNFT.Gego memory gego){
            require(_gegoes[tokenId].id > 0, "gego  not exist");
            gego=_gegoes[tokenId];
    }
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFTReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
