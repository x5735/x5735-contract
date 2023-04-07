// Altura NFT V3 Token
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./dependencies/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract AlturaNFTV3 is ERC1155Upgradeable, AccessControlEnumerableUpgradeable, IERC2981Upgradeable {
    using StringsUpgradeable for string;
    
    uint256 public constant FEE_MAX_PERCENT = 300;
    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant MAX_ITEM_COUNT = 100000000000;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private constant _BITPOS_MAXSUPPLY = 40;
    uint256 private constant _BITPOS_ROYALTYFEE = 80;
    uint256 private constant _BITPOS_ISCONSUMABLE = 95;
    uint256 private constant _BITPOS_CREATOR = 96;
    uint256 private constant _BITMASK_BIT = (1 << 1) - 1;
    uint256 private constant _BITMASK_UINT16_MINUS_ONE_BIT = (1 << 15) - 1;
    uint256 private constant _BITMASK_UINT40 = (1 << 40) - 1;
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;
    uint256 private constant _BITLEN_ADDRESS = 160;

    uint256 private constant _TRANSFER_SINGLE_EVENT_TOPIC = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;
    uint256 private constant _ITEMS_ADDED_EVENT_TOPIC = 0x14d5eddcb78f65ac7fea371e85def32a3ff43483e8253952491ad01c52c6586f;
    bytes4 private constant _INVALID_NEWITEM_ROYALTY_ERROR_SELECTOR = 0x0ea05980;
    
    uint256 public nextItemId;
    string public name;
    bool public isPublic;
    address public factory;
    address public owner;

    uint256[MAX_ITEM_COUNT] private _items;

    struct Item {
        uint256 supply;
        uint256 maxSupply;
        uint256 royaltyFee;
        uint256 isConsumable;
        address creator;
    }

    event ItemsAdded(uint256 from, uint256 count);
    event ItemRoyaltyChanged(uint256 itemId, uint256 newRoyalty);
    event ItemConsumed(uint256 itemId, uint256 amount);

    error InvalidNewItemRoyalty();


    /**
		Initialize from Swap contract
     */
    function initialize(string memory _name, string memory _uri, address _creator, address _factory, bool _isPublic) public initializer {
        __ERC1155_init(_uri);
        __AccessControlEnumerable_init();

        __AlturaERC1155_init_unchained(_name, _creator, _factory, _isPublic);
    }

    function __AlturaERC1155_init_unchained(string memory _name, address _creator, address _factory, bool _isPublic) internal onlyInitializing {
        name = _name;
        owner = _creator;
        factory = _factory;
        isPublic = _isPublic;
        nextItemId = 1;

        _setupRole(DEFAULT_ADMIN_ROLE, _creator);
        _setupRole(MINTER_ROLE, _creator);
    }
    
    /**
		Create Item(s) - Only Minters
     */
    function addItems(uint256[] calldata newItems) external {
        require(nextItemId < MAX_ITEM_COUNT, "Reached max item count");
        require(newItems.length > 0, "Item count can't be 0");
        require(hasRole(MINTER_ROLE, msg.sender) || isPublic, "Only minter can add items");

        // Assembly is utilized to reduce gas expenses, particularly when conducting bulk minting.
        assembly {
            let startId := sload(nextItemId.slot)
            let currentItemId := startId
            let callDataLength := calldatasize()

            for { let offset := newItems.offset }
                lt(offset, callDataLength)
                { offset := add(offset, 0x20) }

                {
                    let itemData := calldataload(offset)
                    let itemInitialSupply := and(itemData, _BITMASK_UINT40)
                    let itemFee := and(shr(_BITPOS_ROYALTYFEE, itemData), _BITMASK_UINT16_MINUS_ONE_BIT)
                    let itemRecipient := and(shr(_BITPOS_CREATOR, itemData), _BITMASK_ADDRESS)

                    if gt(itemFee, FEE_MAX_PERCENT) { 
                        // `revert InvalidNewItemRoyalty()`.
                        mstore(0x00, _INVALID_NEWITEM_ROYALTY_ERROR_SELECTOR)
                        revert(0x00, 0x04)
                    }

                    // `item.creator = msg.sender`.
                    let msgSender := caller()
                    let cleanedItemData := shr(_BITLEN_ADDRESS, shl(_BITLEN_ADDRESS, itemData))
                    itemData := or(cleanedItemData, shl(_BITPOS_CREATOR, msgSender))
                    sstore(add(_items.slot, currentItemId), itemData)

                    if gt(itemInitialSupply, 0x0) {
                        // `_balances[currentItemId][itemRecipient] = itemInitialSupply`.
                        mstore(0x00, currentItemId)
                        mstore(0x20, _balances.slot)
                        mstore(0x20, keccak256(0x00, 0x40))
                        mstore(0x00, itemRecipient)
                        sstore(keccak256(0x00, 0x40), itemInitialSupply)

                        // `emit TransferSingle(msgSender, address(0), itemRecipient, currentItemId, itemInitialSupply)`.
                        mstore(0x00, currentItemId)
                        mstore(0x20, itemInitialSupply)
                        log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_TOPIC, msgSender, 0x0, itemRecipient)
                    }

                    // `currentItemId += 1`.
                    currentItemId := add(currentItemId, 0x1)
                }

            // `emit ItemsAdded(startId, newItems.length)`.
            mstore(0x00, startId)
            mstore(0x20, newItems.length)
            log1(0x00, 0x40, _ITEMS_ADDED_EVENT_TOPIC)

            // `nextItemId = currentItemId`.
            sstore(nextItemId.slot, currentItemId)
        }
    }

    /**
		Mint - Only Minters or Creators
	 */
    function mint(address recipient, uint256 itemId, uint256 amount, bytes memory data) external returns (bool) {
        require(itemId > 0 && itemId < nextItemId, "Invalid item id");
        uint256 itemData = _items[itemId];
        Item memory item = _getItemStruct(itemData);

        require(hasRole(MINTER_ROLE, msg.sender) || item.creator == msg.sender, "Only minter or creator");
        require(item.supply + amount <= item.maxSupply, "Total supply reached");

        // `item.supply += amount`.
        itemData = (itemData & ~_BITMASK_UINT40) | ((item.supply + amount) & _BITMASK_UINT40);
        assembly {
            sstore(add(_items.slot, itemId), itemData)
        }

        _mint(recipient, itemId, amount, data);
        return true;
    }

    /**
		Change Item Royalty Fee - Only Minters or Creators
	 */
    function setItemRoyalty(uint256 itemId, uint256 royaltyFee) external {
        require(itemId > 0 && itemId < nextItemId, "Invalid item id");
        require(royaltyFee < FEE_MAX_PERCENT, "Too big creator fee");
        uint256 itemData = _items[itemId];
        Item memory item = _getItemStruct(itemData);

        require(hasRole(MINTER_ROLE, msg.sender) || item.creator == msg.sender, "Only minter or creator");

        // `item.royaltyFee = royaltyFee`.
        itemData = (itemData & ~(_BITMASK_UINT16_MINUS_ONE_BIT << _BITPOS_ROYALTYFEE)) | royaltyFee << _BITPOS_ROYALTYFEE;
        assembly {
            sstore(add(_items.slot, itemId), itemData)
        }

        emit ItemRoyaltyChanged(itemId, royaltyFee);
    }

    /**
		Consume (Burn) an Item - Only Minters or Creators
	 */
    function consumeItem(address from, uint256 itemId, uint256 amount) external {
        require(itemId > 0 && itemId < nextItemId, "Invalid item id");
        uint256 itemData = _items[itemId];
        Item memory item = _getItemStruct(itemData);

        require(item.isConsumable == 1, "Item not consumable");
        require(hasRole(MINTER_ROLE, msg.sender) || item.creator == msg.sender, "Only minter or creator");

        _burn(from, itemId, amount);
        emit ItemConsumed(itemId, amount);
    }

    /**
		Change Collection Name
	 */
    function setName(string memory newName) external onlyOwner {
        name = newName;
    }

    /**
		Change Collection URI
	 */
    function setURI(string memory newUri) external onlyOwner {
        _setURI(newUri);
    }

    function _getItemStruct(uint256 itemData) internal pure returns (Item memory item) {
        item.supply = itemData & _BITMASK_UINT40;
        item.maxSupply = (itemData >> _BITPOS_MAXSUPPLY) & _BITMASK_UINT40;
        item.royaltyFee = (itemData >> _BITPOS_ROYALTYFEE) & _BITMASK_UINT16_MINUS_ONE_BIT;
        item.isConsumable = (itemData >> _BITPOS_ISCONSUMABLE) & _BITMASK_BIT;
        item.creator = address(uint160((itemData >> _BITPOS_CREATOR) & _BITMASK_ADDRESS));
    }

    function getItem(uint256 itemId) external view returns (Item memory) {
        require(itemId > 0 && itemId < nextItemId, "Invalid item id");
        return _getItemStruct(_items[itemId]);
    }

    function royaltyInfo(uint256 itemId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(itemId > 0 && itemId < nextItemId, "Invalid item id");
        Item memory item = _getItemStruct(_items[itemId]);
        receiver = item.creator;
        royaltyAmount = ((salePrice * item.royaltyFee) / PERCENTS_DIVIDER);
    }

    function uri(uint256 itemId) public view override returns (string memory) {
        string memory _tokenURI = StringsUpgradeable.toString(itemId);
        string memory _baseURI = super.uri(itemId);

        return string(abi.encodePacked(_baseURI, _tokenURI));
    }

    function isApprovedForAll(address account, address operator) public view virtual override(ERC1155Upgradeable) returns (bool) {
        return operator == factory || super.isApprovedForAll(account, operator);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual
        override(ERC1155Upgradeable, AccessControlEnumerableUpgradeable, IERC165Upgradeable) returns (bool) 
    {
        return type(IERC2981Upgradeable).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

    modifier onlyOwner() {
        require(owner == _msgSender(), "Caller is not the owner");
        _;
    }

    receive() external payable {
        revert();
    }
}