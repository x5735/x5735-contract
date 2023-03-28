// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @author Brewlabs
 * This contract has been developed by brewlabs.info
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721, ERC721Enumerable, IERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract ThePixelKeeper is Ownable, ERC721Enumerable, ReentrancyGuard, DefaultOperatorFilterer {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 private constant MAX_SUPPLY = 500;
    bool public mintAllowed = false;

    string private _tokenBaseURI = "";
    mapping(uint256 => string) private _tokenURIs;

    // minting prices of rarities([super rare, rare, common])
    uint256[3] public prices = [250 ether, 150 ether, 100 ether];
    uint256[3] public stakingFees = [87.5 ether, 37.5 ether, 20 ether];
    IERC20 public feeToken = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    uint256 public oneTimeMintLimit = 10;

    address public staking;
    address public feeWallet = 0x7BbC3Ca369Fb1567b65152De8149Ae9D85685047;
    address public treasury = 0x5Ac58191F3BBDF6D037C6C6201aDC9F99c93C53A;
    uint256 public performanceFee = 0.0035 ether;

    uint256[3] public mintCntForRarity;
    string[3] public rarityNames = ["Super Rare", "Rare", "Common"];
    mapping(uint256 => uint256) public rarityOfItem;

    uint256[][3] private tokenIdsOfRarity;
    uint256[3] private lastTokenIndexes = [0, 0, 0];
    mapping(uint256 => bool) private notExistsInCommon;
    mapping(address => bool) private whitelist;

    event MintEnabled();
    event Mint(address indexed user, uint256 tokenId);
    event BaseURIUpdated(string uri);

    event SetFeeToken(address token);
    event SetMintPrices(uint256[3] prices);
    event SetStakingFees(uint256[3] fees);
    event SetOneTimeMintLimit(uint256 limit);

    event SetFeeWallet(address wallet);
    event SetStakingWallet(address wallet);
    event ServiceInfoUpadted(address _addr, uint256 _fee);
    event AdminTokenRecovered(address tokenRecovered, uint256 amount);

    event AddWhitelist(address addr);
    event RemoveWhitelist(address addr);

    modifier onlyMintable() {
        require(mintAllowed && totalSupply() < MAX_SUPPLY, "Cannot mint");
        _;
    }

    constructor() ERC721("The Pixel Keeper", "TPK") {
        feeWallet = msg.sender;
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override (ERC721, IERC721)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function mint(uint256 _rarity, uint256 _numToMint) external payable onlyMintable nonReentrant {
        require(_rarity < 3, "Invalid rarity");
        require(_numToMint > 0, "Invalid amount");
        require(_numToMint <= oneTimeMintLimit, "Exceed one-time mint limit");
        require(totalSupply() + _numToMint <= MAX_SUPPLY, "Cannot exceed supply");
        require(
            (
                _rarity == 2
                    && (mintCntForRarity[2] + _numToMint <= MAX_SUPPLY - tokenIdsOfRarity[0].length - tokenIdsOfRarity[1].length)
            ) || lastTokenIndexes[_rarity] + _numToMint <= tokenIdsOfRarity[_rarity].length,
            "No tokens to mint for this rarity"
        );

        _transferPerformanceFee();

        if (!whitelist[msg.sender]) {
            uint256 price = prices[_rarity] * _numToMint;
            uint256 fee = stakingFees[_rarity] * _numToMint;
            feeToken.safeTransferFrom(msg.sender, staking, fee);
            feeToken.safeTransferFrom(msg.sender, feeWallet, price - fee);
        }

        for (uint256 i = 0; i < _numToMint; i++) {
            uint256 tokenId;
            if (_rarity < 2) {
                tokenId = tokenIdsOfRarity[_rarity][lastTokenIndexes[_rarity]];
                lastTokenIndexes[_rarity]++;
            } else {
                tokenId = lastTokenIndexes[_rarity] + 1;
                while (tokenId <= MAX_SUPPLY) {
                    if (!notExistsInCommon[tokenId]) break;
                    tokenId++;
                }
                lastTokenIndexes[_rarity] = tokenId;
                if (tokenId > MAX_SUPPLY) return;
            }
            mintCntForRarity[_rarity]++;
            rarityOfItem[tokenId] = _rarity;

            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, tokenId.toString());
            emit Mint(msg.sender, tokenId);
        }

        if (totalSupply() == MAX_SUPPLY) mintAllowed = false;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_baseURI(), "/", _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function rarityOf(uint256 tokenId) external view returns(string memory) {
        return rarityNames[rarityOfItem[tokenId]];
    }

    function enableMint() external onlyOwner {
        require(!mintAllowed, "Already enabled");
        require(staking != address(0x0), "Not set staking address");
        require(tokenIdsOfRarity[0].length > 0 && tokenIdsOfRarity[1].length > 0, "TokenId list not configured");

        mintAllowed = true;
        emit MintEnabled();
    }

    function setMintPrices(uint256[3] memory _prices) external onlyOwner {
        prices = _prices;
        emit SetMintPrices(_prices);
    }

    function setStakingFees(uint256[3] memory _fees) external onlyOwner {
        stakingFees = _fees;
        emit SetStakingFees(_fees);
    }

    function setFeeToken(address _token) external onlyOwner {
        require(_token != address(0x0), "Invalid token");
        require(_token != address(feeToken), "Already set");
        require(!mintAllowed, "Mint was enabled");

        feeToken = IERC20(_token);
        emit SetFeeToken(_token);
    }

    function setTokenIdsForRarity(uint256 _rarity, uint256[] memory _tokenIds) external onlyOwner {
        require(!mintAllowed, "Mint already started");
        require(totalSupply() < MAX_SUPPLY, "Mint was finished");
        require(_rarity < 2, "Invalid rarity");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            tokenIdsOfRarity[_rarity].push(tokenId);
            notExistsInCommon[tokenId] = true;
        }
    }

    function removeTokenIdsForRarity(uint256 _rarity, uint256 _tokenId) external onlyOwner {
        require(!mintAllowed, "Mint already started");
        require(totalSupply() < MAX_SUPPLY, "Mint was finished");
        require(_rarity < 2, "Invalid rarity");

        uint256 indexOfTokenId = 0;
        for (uint256 i = 0; i < tokenIdsOfRarity[_rarity].length; i++) {
            uint256 tokenId = tokenIdsOfRarity[_rarity][i];
            if (tokenId == _tokenId) {
                indexOfTokenId = i + 1;
                break;
            }
        }
        require(indexOfTokenId > 0, "Not exist in tokenId list");

        tokenIdsOfRarity[_rarity][indexOfTokenId - 1] = tokenIdsOfRarity[_rarity][tokenIdsOfRarity[_rarity].length - 1];
        tokenIdsOfRarity[_rarity].pop();
        notExistsInCommon[_tokenId] = false;
    }

    function setTokenBaseUri(string memory _uri) external onlyOwner {
        _tokenBaseURI = _uri;
        emit BaseURIUpdated(_uri);
    }

    function setOneTimeMintLimit(uint256 _limit) external onlyOwner {
        require(_limit <= 50, "Cannot exceed 50");
        oneTimeMintLimit = _limit;
        emit SetOneTimeMintLimit(_limit);
    }

    function setAdminWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0x0), "Invalid address");
        feeWallet = _wallet;
        emit SetFeeWallet(_wallet);
    }

    function setStakingWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0x0), "Invalid address");
        staking = _wallet;
        emit SetStakingWallet(_wallet);
    }

    function addToWhitelist(address _addr) external onlyOwner {
        require(_addr != address(0x0), "Invalid address");
        whitelist[_addr] = true;
        emit AddWhitelist(_addr);
    }

    function removeFromWhitelist(address _addr) external onlyOwner {
        require(_addr != address(0x0), "Invalid address");
        whitelist[_addr] = false;
        emit RemoveWhitelist(_addr);
    }

    function setServiceInfo(address _addr, uint256 _fee) external {
        require(msg.sender == treasury, "SetServiceInfo: FORBIDDEN");
        require(_addr != address(0x0), "Invalid address");

        treasury = _addr;
        performanceFee = _fee;
        emit ServiceInfoUpadted(_addr, _fee);
    }

    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0x0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            IERC20(_token).transfer(address(msg.sender), _amount);
        }

        emit AdminTokenRecovered(_token, _amount);
    }

    function _transferPerformanceFee() internal {
        require(msg.value >= performanceFee, "Should pay small gas to mint");

        payable(treasury).transfer(performanceFee);
        if (msg.value > performanceFee) {
            payable(msg.sender).transfer(msg.value - performanceFee);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    receive() external payable {}
}