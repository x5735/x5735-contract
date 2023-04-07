// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/Context.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LlamaLandRelic.sol";
import "./LlamaLandRelicMetadata.sol";

contract LlamaLandRelicStore is Context, AccessControl, ERC1155Holder {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CREATE_ROLE = keccak256("CREATE_ROLE");
    bytes32 public constant SET_PRICE_ROLE = keccak256("SET_PRICE_ROLE");
    bytes32 public constant LAUNCH_ROLE = keccak256("LAUNCH_ROLE");
    bytes32 public constant SET_CASHIER_ROLE = keccak256("SET_CASHIER_ROLE");

    struct Item {
        uint tokenId;
        uint price;
        bool exists;
        bool isLaunched;
    }

    uint[] public itemIdList;
    mapping(uint => Item) public itemMap;
    address public cashier;

    event Create(uint tokenId, uint32 amount);
    event CreateBatch(uint[] tokenIdList, uint32[] amountList);
    event Buy(address from, uint tokenId, uint32 amount);
    event BuyBatch(address from, uint[] tokenIdList, uint32[] amountList);
    event SetPrice(uint tokenId, uint price);
    event SetPriceBatch(uint[] tokenIdList, uint[] priceList);
    event Launch(uint tokenId, bool isLaunched);
    event LaunchBatch(uint[] tokenIdList, bool[] isLaunchedList);
    event SetCashier(address to);

    LlamaLandRelic relic;
    LlamaLandRelicMetadata metadata;
    ERC20 lhc;

    constructor(address _relic, address _metadata, address _lhc, address _cashier) {
        relic = LlamaLandRelic(_relic);
        metadata = LlamaLandRelicMetadata(_metadata);
        lhc = ERC20(_lhc);
        cashier = _cashier;

        _grantRole(OWNER_ROLE, owner());
        _grantRole(ADMIN_ROLE, admin());
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);

        _setRoleAdmin(CREATE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SET_PRICE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(LAUNCH_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SET_CASHIER_ROLE, ADMIN_ROLE);
    }

    function owner() view public returns (address) {
        return relic.owner();
    }

    function admin() view public returns (address) {
        return relic.admin();
    }

    function getItemAmount()
    view
    external
    returns (uint) {
        return itemIdList.length;
    }

    function getItemIdList()
    view
    external
    returns (uint[] memory) {
        return itemIdList;
    }

    function _create(string memory cid, uint price, uint32 amount, uint32[6] memory abilities)
    private
    returns (uint) {
        uint tokenId = relic.serialNo();
        relic.mint(address(this), cid, amount);
        metadata.update(tokenId, cid, abilities);
        itemIdList.push(tokenId);
        itemMap[tokenId] = Item(tokenId, price, true, false);
        return tokenId;
    }

    function create(string memory cid, uint price, uint32 amount, uint32[6] memory abilities)
    onlyRole(CREATE_ROLE)
    external {
        uint tokenId = _create(cid, price, amount, abilities);
        emit Create(tokenId, amount);
    }

    function createBatch(string[] memory cidList, uint[] memory priceList, uint32[] memory amountList, uint32[6][] memory abilitiesList)
    onlyRole(CREATE_ROLE)
    external {
        uint[] memory tokenIdList = new uint[](cidList.length);
        for (uint index = 0; index < cidList.length; index++) {
            string memory cid = cidList[index];
            uint price = priceList[index];
            uint32 amount = amountList[index];
            uint32[6] memory abilities = abilitiesList[index];
            uint tokenId = _create(cid, price, amount, abilities);
            tokenIdList[index] = tokenId;
        }
        emit CreateBatch(tokenIdList, amountList);
    }

    function _checkItem(bool exists)
    pure
    private {
        require(exists == true, "Token ID is nonexistent");
    }

    function _buy(uint tokenId, uint32 amount, uint price, address to)
    private {
        Item memory item = itemMap[tokenId];
        _checkItem(item.exists);
        require(item.isLaunched == true, "The item is discontinued");
        require(amount <= relic.balanceOf(address(this), tokenId), "The amount is more than the maximum value");
        require(price == (itemMap[tokenId].price * amount), "LHC is insufficient");
        lhc.transferFrom(_msgSender(), cashier, price);
        relic.safeTransferFrom(address(this), to, tokenId, amount, "");
    }

    function buy(uint tokenId, uint32 amount, uint price, address to)
    external {
        _buy(tokenId, amount , price, to);
        emit Buy(_msgSender(), tokenId, amount);
    }

    function buyBatch(uint[] memory tokenIdList, uint32[] memory amountList, uint[] memory priceList, address[] memory toList)
    external {
        for (uint index = 0; index < tokenIdList.length; index++) {
            uint tokenId = tokenIdList[index];
            uint32 amount = amountList[index];
            uint price = priceList[index];
            address to = toList[index];
            _buy(tokenId, amount, price, to);
        }
        emit BuyBatch(_msgSender(), tokenIdList, amountList);
    }

    function _setPrice(uint tokenId, uint price)
    private {
        Item storage item = itemMap[tokenId];
        _checkItem(item.exists);
        item.price = price;
    }

    function setPrice(uint tokenId, uint price)
    onlyRole(SET_PRICE_ROLE)
    external {
        _setPrice(tokenId, price);
        emit SetPrice(tokenId, price);
    }

    function setPriceBatch(uint[] memory tokenIdList, uint[] memory priceList)
    onlyRole(SET_PRICE_ROLE)
    external {
        for (uint index = 0; index < tokenIdList.length; index++) {
            uint tokenId = tokenIdList[index];
            uint price = priceList[index];
            _setPrice(tokenId, price);
        }
        emit SetPriceBatch(tokenIdList, priceList);
    }

    function _launch(uint tokenId, bool isLaunched)
    private {
        Item storage item = itemMap[tokenId];
        _checkItem(item.exists);
        item.isLaunched = isLaunched;
    }

    function launch(uint tokenId, bool isLaunched)
    onlyRole(LAUNCH_ROLE)
    external {
        _launch(tokenId, isLaunched);
        emit Launch(tokenId, isLaunched);
    }

    function launchBatch(uint[] memory tokenIdList, bool[] memory isLaunchedList)
    onlyRole(LAUNCH_ROLE)
    external {
        for (uint index = 0; index < tokenIdList.length; index++) {
            uint tokenId = tokenIdList[index];
            bool isLaunched = isLaunchedList[index];
            _launch(tokenId, isLaunched);
        }
        emit LaunchBatch(tokenIdList, isLaunchedList);
    }

    function setCashier(address to)
    onlyRole(SET_CASHIER_ROLE)
    external {
        cashier = to;
        emit SetCashier(to);
    }

    function destroy() external {
        require(_msgSender() == owner(), "Caller is not the owner");
        selfdestruct(payable(owner()));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC1155Receiver)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}