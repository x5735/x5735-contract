// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interface/ISFTToken.sol";

contract BusinessMinter is Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    struct Record {
        string label; 
        string minerId; // miner actor Id
        uint sendAmount; // send FIL amount this transfer record
        uint mintedAmount; // already minted SFT Amount
        address recipient; // recipient of minted SFT for this record
    }

    EnumerableSet.Bytes32Set private messageIdList; // list of hash(messageId)

    ISFTToken public sftToken;
    address public recorder;
    address public minter; 
    mapping (string => bytes32) public messageIdToHash; // messageId => hash(messageId)
    mapping (bytes32 => string) public hashToMessageId; // hash(messageId) => messageId
    mapping (string => Record) public record; // transfer messageId on filecoin chain => Record

    event AddRecord(string messageId, string minerId, address recipient, uint sendAmount, string label);
    event UpdateRecord(string messageId, string minerId, address recipient, uint newSendAmount, string newLabel);
    event RemoveRecord(string messageId);
    event Mint(string[] messageIds, uint[] amounts);
    event MintToRecipient(address recipient, string messageId, uint amount);
    event SetRecorder(address oldRecorder, address newRecorder);
    event SetMinter(address oldMinter, address newMinter);

    modifier onlyRecorder() {
        require(address(msg.sender) == recorder, "BusinessMinter: noly recorder can call");
        _;
    }

    function initialize(ISFTToken _sftToken, address _recorder, address _minter) external initializer {
        require(address(_sftToken) != address(0), "SFT token address cannot be zero");
        __Context_init_unchained();
        __Ownable_init_unchained();
        sftToken = _sftToken;
        _setRecorder(_recorder);
        _setMinter(_minter);
    }

    function setRecorder(address newRecorder) external onlyOwner {
        _setRecorder(newRecorder);
    }

    function _setRecorder(address _recorder) private {
        emit SetRecorder(recorder, _recorder);
        recorder = _recorder;
    }

    function setMinter(address newMinter) external onlyOwner {
        _setMinter(newMinter);
    }

    function _setMinter(address _minter) private {
        emit SetMinter(minter, _minter);
        minter = _minter;
    }

    function getMessagIdList() public view returns (string[] memory) {
        bytes32[] memory hashList = messageIdList.values();
        string[] memory idList = new string[](hashList.length);
        for (uint i = 0; i < hashList.length; i++) {
            idList[i] = hashToMessageId[hashList[i]];
        }
        return idList;
    }

    function isRecordExist(string calldata messageId) public view returns (bool) {
        return messageIdList.contains(messageIdToHash[messageId]);
    }

    function addRecord(string calldata messageId, string calldata _minerId, address _recipient, uint _sendAmount, string calldata _label) external onlyRecorder {
        require(_recipient != address(0), "recipient is zero");
        bytes32 messageIdHash = keccak256(abi.encode(messageId));
        require(!messageIdList.contains(messageIdHash), "record already be added");
        Record storage r = record[messageId];
        r.minerId = _minerId;
        r.recipient = _recipient;
        r.sendAmount = _sendAmount;
        r.label = _label;
        messageIdToHash[messageId] = messageIdHash;
        hashToMessageId[messageIdHash] = messageId;
        messageIdList.add(messageIdHash);
        emit AddRecord(messageId, _minerId, _recipient, _sendAmount, _label);
    }

    function updateRecord(string calldata messageId, string calldata newMinerId, address newRecipient, uint newSendAmount, string calldata newLabel) external onlyRecorder {
        require(newRecipient != address(0), "recipient is zero");
        bytes32 messageIdHash = keccak256(abi.encode(messageId));
        require(messageIdList.contains(messageIdHash), "record hasn't added yet");
        Record storage r = record[messageId];
        r.minerId = newMinerId;
        r.recipient = newRecipient;
        r.sendAmount = newSendAmount;
        r.label = newLabel;
        emit UpdateRecord(messageId, newMinerId, newRecipient, newSendAmount, newLabel);
    }

    function removeRecord(string calldata messageId) external onlyRecorder {
        bytes32 messageIdHash = keccak256(abi.encode(messageId));
        require(messageIdList.contains(messageIdHash), "record hasn't added yet");
        messageIdList.remove(messageIdHash);
        delete messageIdToHash[messageId];
        delete hashToMessageId[messageIdHash];
        delete record[messageId];
        emit RemoveRecord(messageId);
    }

    function mint(string[] calldata messageIds, uint[] calldata amounts) external {
        require(address(msg.sender) == minter, "BusinessMinter: only minter can call");
        require(messageIds.length > 0 && messageIds.length == amounts.length, "incorrect params");
        for (uint i = 0; i < messageIds.length; i++) {
            _mint(messageIds[i], amounts[i]);
        }
        emit Mint(messageIds, amounts);
    }

    function _mint(string memory messageId, uint amount) internal {
        bytes32 messageIdHash = keccak256(abi.encode(messageId));
        require(messageIdList.contains(messageIdHash), "record hasn't added yet");
        Record storage r = record[messageId];
        require(r.mintedAmount + amount <= r.sendAmount, "minted amount can't exceed send amount");
        r.mintedAmount += amount;
        sftToken.mint(r.recipient, amount);
        emit MintToRecipient(r.recipient, messageId, amount);
    }
}