// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

//* Receivers
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

//** Overrides OpenZeppelin */
import "contracts/overrides/openzeppelin/metatx/ERC2771ContextUpgradeable.sol";

//** Overrides Chainlink */
import "contracts/overrides/chainlink/VRFConsumerBaseV2Upgradeable.sol";

import "contracts/base/TokenStore.sol";

contract FoxtrotCrates is
	Initializable,
	OwnableUpgradeable,
	AccessControlUpgradeable,
	ERC1155Upgradeable,
	ERC2771ContextUpgradeable,
	VRFConsumerBaseV2Upgradeable,
	ReentrancyGuardUpgradeable,
	TokenStore
{
	bytes32 private minterRole;
	string public name;
	string public symbol;
	uint256 public totalSupply;

	mapping(uint256 => uint256) public totalSupplyOfToken;

	/*///////////////////////////////////////////////////////////////
                            VRF state
    //////////////////////////////////////////////////////////////*/

	VRFCoordinatorV2Interface private coordinator;
	uint64 private sSubscriptionId;
	bytes32 private keyHash;
	bytes32 private chainlinkRole;
	uint32 private constant CALLBACKGASLIMIT = 100_000;
	uint16 private constant REQUEST_CONFIRMATIONS = 3;
	uint32 private constant NUMWORDS = 2;

	struct RequestInfo {
		CrateType crateType;
		bool openOnFulfillRandomness;
		address opener;
		uint256 crateId;
		uint256 amountToOpen;
		uint256[] randomWords;
	}

	mapping(uint256 => RequestInfo) private requestInfo;
	mapping(address => uint256) private openerToReqId;

	event CrateOpenRequest(
		address opener,
		uint256 createId,
		CrateType crateType,
		uint256 requestId
	);
	event CrateRamdonessFulfilled(uint256 crateId, uint256 requestId);

	function initialize(
		address _defaultAdmin,
		string memory _name,
		string memory _symbol,
		string memory _contractURI,
		address[] memory trustedForward,
		uint64 subscriptionId,
		address _vrfCoordinator
	) external initializer {
		bytes32 _minterRole = keccak256("MINTER_ROLE");
		bytes32 _chainlinkRole = keccak256("CHAINLINK_HELPER_ROLE");

		__ERC2771Context_init(trustedForward);
		__Ownable_init();
		__ERC1155_init(_contractURI);

		name = _name;
		symbol = _symbol;

		__AccessControl_init();
		__Ownable_init();
		_setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
		_setupRole(_minterRole, _defaultAdmin);
		_setupRole(_chainlinkRole, _defaultAdmin);

		__VRFConsumerBaseV2Upgradeable_init(_vrfCoordinator);
		sSubscriptionId = subscriptionId;
		coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);

		minterRole = _minterRole;
		chainlinkRole = _chainlinkRole;
	}

	/*#################################################################
							ERC1155 Common Overrides
	#################################################################*/

	/// @dev Returns the URI for a given crateId.
	function uri(uint256 _crateId) public view override returns (string memory) {
		return _uriOfBundle(_crateId);
	}

	/*#################################################################
							Chainlink VRF
	#################################################################*/

	/**
	 * @dev Set the subscription ID for the oracle
	 * @param _subscriptionId The subscription ID to set
	 */
	function setVRFSubscriptionId(uint64 _subscriptionId) external onlyRole(chainlinkRole) {
		require(_subscriptionId != 0, "VRF: !Sub0");
		sSubscriptionId = _subscriptionId;
	}

	/**
	 * @dev Set the key hash for the oracle
	 * @param _keyHash The key hash to set
	 */
	function setKeyHash(bytes32 _keyHash) external onlyRole(chainlinkRole) {
		keyHash = _keyHash;
	}

	/**
	 * @dev Receive the VRF response
	 *		This method normally is called fulfillRandomWords
	 * @param _requestId The request id to use
	 * @param _randomWords Array of random words
	 */
	function pickItemFromCrate(
		uint256 _requestId,
		uint256[] memory _randomWords
	) internal override {
		RequestInfo memory info = requestInfo[_requestId];

		require(info.randomWords.length == 0, "FCCr: VAF");
		requestInfo[_requestId].randomWords = _randomWords;

		emit CrateRamdonessFulfilled(info.crateId, _requestId);

		try FoxtrotCrates(payable(address(this))).sendRewardsIndirect(info.opener) {} catch {}
	}

	/*#################################################################
                            Create Pack Logic
    #################################################################*/
	struct CrateInfo {
		CrateType crateType;
		uint128 openStartTimestamp;
		uint128 amountDistributedPerOpen;
	}

	mapping(uint256 => CrateInfo) private crateInfo;

	/// @notice Emitted when a set of packs is created.
	event CrateCreated(uint256 indexed crateId, address recipient, uint256 totalPacksCreated);
	event CrateOpened(
		uint256 indexed crateId,
		address indexed opener,
		uint256 numOfCratesOpened,
		Token[] items
	);

	/**
	 * @dev Create a crate by rarity
	 * @param _items The items to be distributed
	 * @param _probabilities The probabilities of each item
	 * @param _crateUri The URI of the crate
	 * @param _crateId The crate id to be created
	 * @param _totalCrates The total amount of crates to be created
	 * @param _rewardsPerCrate The amount of rewards per crate
	 * @param _openStartTimestamp The timestamp when the crate can be opened
	 */
	function createCrateByRarity(
		Token[] calldata _items,
		uint256[][] memory _probabilities,
		string memory _crateUri,
		uint256 _crateId,
		uint256 _totalCrates,
		uint128 _rewardsPerCrate,
		uint128 _openStartTimestamp
	)
		external
		payable
		onlyRole(minterRole)
		nonReentrant
		returns (uint256 crateId, uint256 crateTotalSupply)
	{
		require(_items.length > 0, "FCCr: !NI#F");
		require(_probabilities.length <= _rewardsPerCrate, "FCCr: !PRC");

		crateId = _crateId;
		crateTotalSupply = _totalCrates;

		crateInfo[crateId].openStartTimestamp = _openStartTimestamp;
		crateInfo[crateId].amountDistributedPerOpen = _rewardsPerCrate;
		crateInfo[crateId].crateType = CrateType.RARITY_CRATE;

		_mint(_msgSender(), crateId, crateTotalSupply, "");
		_storeTokens(
			_msgSender(),
			_items,
			_crateUri,
			crateId,
			_probabilities,
			CrateType.RARITY_CRATE
		);
		emit CrateCreated(crateId, _msgSender(), _totalCrates);
	}

	//** OPEN LOGIC */

	/**
	 * @dev Open a crate by rarity
	 * @param _crateId The crate id to open
	 * @param _amountToOpen The amount of crates to open
	 * @param _callBackGasLimit The amount of gas to use during the claiming
	 * @return uint256 The request id
	 */
	function openCrateAndClaimRewards(
		uint256 _crateId,
		uint256 _amountToOpen,
		uint32 _callBackGasLimit
	) external returns (uint256) {
		uint32 requestedRandoms = 2;
		return
			_requestOpenCrate(
				CrateType.RARITY_CRATE,
				_crateId,
				_amountToOpen,
				requestedRandoms,
				_callBackGasLimit,
				true
			);
	}

	/**
	 * @dev Open a crate by rarity
	 * @param _crateId The crate id to open
	 * @param _amountToOpen The amount of crates to open
	 * @return uint256 The request id
	 */
	function openCrate(uint256 _crateId, uint256 _amountToOpen) external returns (uint256) {
		uint32 requestedRandoms = 2;
		return
			_requestOpenCrate(
				CrateType.RARITY_CRATE,
				_crateId,
				_amountToOpen,
				requestedRandoms,
				CALLBACKGASLIMIT,
				false
			);
	}

	/**
	 * @notice send rewards to the opener
	 * @param _opener the address of the opener
	 */
	function sendRewardsIndirect(address _opener) external {
		require(_msgSender() == address(this), "FCCr: !OCI");
		uint256 requestId = openerToReqId[_opener];
		RequestInfo memory info = requestInfo[requestId];

		if (info.crateType == CrateType.RARITY_CRATE) {
			_openRarityCrate(_opener);
		}
	}

	/**
	 * @notice claim rewards
	 * @dev this function is used to claim rewards if the opener
	 *		already call the openCrate function
	 */
	function claimRewards() external returns (Token[] memory) {
		return _openRarityCrate(_msgSender());
	}

	/**
	 * @notice check if the opener can collect rewards
	 * @param _opener the address of the opener
	 */
	function canCollectRewards(address _opener) public view returns (bool) {
		uint256 requestId = openerToReqId[_opener];
		return requestId > 0 && requestInfo[requestId].randomWords.length > 0;
	}

	/**
	 * @dev Set the chain native token wrapper address
	 * @param newAddress address of the chain native token wrapper
	 */
	function setChainNativeTokenWrapperAddress(
		address newAddress
	) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
		_setChainNativeTokenWrapperAddress(newAddress);
		return true;
	}

	/**
	 * @dev Get the chain native token wrapper address
	 * @return address of the chain native token wrapper
	 */
	function getChainNativeTokenWrapperAddress() external view returns (address) {
		return _getChainNativeTokenWrapperAddress();
	}

	/**
	 * @dev Open a crate by rarity
	 * @param _type The Crate Type to open
	 * @param _crateId The crate id to open
	 * @param _amountToOpen The amount of crates to open
	 * @param _requestedRandoms The id of the requested random numbers
	 * @param _callBackGasLimit The amount of gas to use during the opening
	 * @param _openOnFulfill Should the crate be opened on fulfill
	 * @return requestId The requested id
	 */
	function _requestOpenCrate(
		CrateType _type,
		uint256 _crateId,
		uint256 _amountToOpen,
		uint32 _requestedRandoms,
		uint32 _callBackGasLimit,
		bool _openOnFulfill
	) internal returns (uint256 requestId) {
		address opener = _msgSender();

		require(isTrustedForwarder(_msgSender()) || opener == tx.origin, "FCCr: !EOA");
		require(openerToReqId[opener] == 0, "FCCr: !VRF#F");
		require(_amountToOpen > 0, "FCCr: !OOB#F");
		require(
			crateInfo[_crateId].openStartTimestamp <= block.timestamp ||
				crateInfo[_crateId].openStartTimestamp == 0,
			"FCCr: !CNA#F"
		);

		_safeTransferFrom(opener, address(this), _crateId, _amountToOpen, "");

		requestId = coordinator.requestRandomWords(
			keyHash,
			sSubscriptionId,
			REQUEST_CONFIRMATIONS,
			_callBackGasLimit,
			_requestedRandoms
		);

		requestInfo[requestId].crateId = _crateId;
		requestInfo[requestId].crateType = _type;
		requestInfo[requestId].opener = opener;
		requestInfo[requestId].amountToOpen = _amountToOpen;
		requestInfo[requestId].openOnFulfillRandomness = _openOnFulfill;
		openerToReqId[opener] = requestId;

		emit CrateOpenRequest(opener, _crateId, _type, requestId);
	}

	/**
	 * @dev Iterate through total items to pick items based on probabilitie
	 * @param _crateId crate id
	 * @param randomWords random words array
	 * @param _unitsPerOpen total items
	 * @return array of rarities
	 */
	function _pickRarities(
		uint256 _crateId,
		uint256[] memory randomWords,
		uint256 _unitsPerOpen,
		uint256 _amountToOpen
	) internal view returns (uint256[] memory) {
		uint256[] memory pickedRarities = new uint256[](_unitsPerOpen * _amountToOpen);

		uint256 probabilityIndex = getProbabilityOfCrate(_crateId).length;
		uint256 counter;
		for (uint256 i; i < _unitsPerOpen; i++) {
			if (probabilityIndex > 0) {
				probabilityIndex -= 1;
			}
			for (uint256 j; j < _amountToOpen; j++) {
				pickedRarities[counter] = uint256(
					_pickRarityByProbability(
						_crateId,
						uint256(keccak256(abi.encode(randomWords[0], counter, block.timestamp))) %
							100 ether,
						probabilityIndex
					)
				);
				counter++;
			}
		}

		return pickedRarities;
	}

	/**
	 * @notice returns the crate contents
	 * @dev this function is used to get crate contents
	 * @param _crateId uint256 crate id
	 * @param randomWords uint256[] random words
	 * @return Token[] crate contents
	 */
	function getCrateContent(
		uint256 _crateId,
		uint256 _amountToOpen,
		uint256[] memory randomWords
	) internal view returns (Token[] memory) {
		uint256 rewardsPerOpen = crateInfo[_crateId].amountDistributedPerOpen;
		uint256[] memory rarityOfCratePacked = _calculateRarities(_crateId);
		uint256 totalItemsInCrate = getTokenCountOfBundle(_crateId);

		// Pick rarities based on probabilities of the Crate
		uint256[] memory pickedRarities = _pickRarities(
			_crateId,
			randomWords,
			rewardsPerOpen,
			_amountToOpen
		);

		// This method recover the items of the crate orderer by Rarity
		// Also includes the length so it can be the selector for give the correct card
		// given a random number
		Token[][] memory items = new Token[][](5);
		items = _filterRaritiesAndClassifiedIt(_crateId, rarityOfCratePacked, totalItemsInCrate);

		uint256 totalItemsToOpen = rewardsPerOpen * _amountToOpen;
		Token[] memory itemsToSendToOpener = new Token[](totalItemsToOpen);

		for (uint256 i; i < totalItemsToOpen; i++) {
			uint256 random = uint256(keccak256(abi.encode(randomWords[0], i))) % 100 ether;

			// The (- 1) indicates the conversion from Rarity 1-5 to index 0-4
			uint256 raritySelector = pickedRarities[i] - 1;

			Token memory selectedItem = items[raritySelector][
				random % items[raritySelector].length
			];

			itemsToSendToOpener[i] = Token({
				assetContract: selectedItem.assetContract,
				tokenType: selectedItem.tokenType,
				tokenId: selectedItem.tokenId,
				totalAmount: 1,
				isMintRequired: selectedItem.isMintRequired,
				rarity: selectedItem.rarity
			});
		}

		return itemsToSendToOpener;
	}

	/**
	 * @notice open a rarity crate
	 * @param _opener the address of the opener
	 */
	function _openRarityCrate(address _opener) internal returns (Token[] memory) {
		require(canCollectRewards(_opener), "FCCr: !CCR#F");
		uint256 requestId = openerToReqId[_opener];

		RequestInfo memory info = requestInfo[requestId];
		uint256 crateId = info.crateId;

		delete openerToReqId[_opener];
		delete requestInfo[requestId];

		Token[] memory itemsToSendToOpener = getCrateContent(
			crateId,
			info.amountToOpen,
			info.randomWords
		);

		// Burn packs.
		_burn(address(this), info.crateId, info.amountToOpen);

		// Transfer items to the opener.
		_handleSendCrateItemsToRequester(address(this), _opener, itemsToSendToOpener);

		emit CrateOpened(info.crateId, _opener, info.amountToOpen, itemsToSendToOpener);

		return itemsToSendToOpener;
	}

	receive() external payable {}

	function _beforeTokenTransfer(
		address operator,
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts,
		bytes memory data
	) internal virtual override {
		super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

		if (from == address(0)) {
			for (uint256 i = 0; i < ids.length; i++) {
				totalSupplyOfToken[ids[i]] += amounts[i];
				totalSupply += amounts[i];
			}
		}

		if (to == address(0)) {
			for (uint256 i = 0; i < ids.length; i++) {
				totalSupplyOfToken[ids[i]] -= amounts[i];
				totalSupply -= amounts[i];
			}
		}
	}

	/// @dev See ERC 165
	function supportsInterface(
		bytes4 interfaceId
	)
		public
		view
		virtual
		override(ERC1155ReceiverUpgradeable, ERC1155Upgradeable, AccessControlUpgradeable)
		returns (bool)
	{
		return
			super.supportsInterface(interfaceId) ||
			type(IERC2981Upgradeable).interfaceId == interfaceId ||
			type(IERC721Receiver).interfaceId == interfaceId ||
			type(IERC1155Receiver).interfaceId == interfaceId;
	}

	/// @dev See EIP-2771
	function _msgSender()
		internal
		view
		virtual
		override(ContextUpgradeable, ERC2771ContextUpgradeable)
		returns (address sender)
	{
		return ERC2771ContextUpgradeable._msgSender();
	}

	/// @dev See EIP-2771
	function _msgData()
		internal
		view
		virtual
		override(ContextUpgradeable, ERC2771ContextUpgradeable)
		returns (bytes calldata)
	{
		return ERC2771ContextUpgradeable._msgData();
	}
}