//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Phoenix is Ownable, ReentrancyGuard, ERC1155Holder {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct Quest {
        uint256 questId;
        address tokenContractAddress;
        uint256 totalNumberOfQuests;
        uint256 numberOfQuestsCompleted;
        uint256[] inputTokenIds;
        uint256[] outputTokenIds;
        uint256[] inputTokenQuantities;
        uint256[] outputTokenQuantity;
        address operator;
        bool multipleParticipation;
        uint256 startBlock;
        uint256 endBlock;
        bool valid;
    }

    mapping(uint256 => Quest) private quest;

    // @dev: questId => wallet address => participation (bool)
    mapping(uint256 => mapping(address => bool)) walletQuestParticipation;

    // @dev: list of created ins ids
    uint256[] private createdQuestIds;

    Counters.Counter private _questIds;

    address private deadContract = 0x000000000000000000000000000000000000dEaD;

    modifier completeBlockRange(uint256 _questId) {
        Quest storage questConfiguration = quest[_questId];
        require(
            questConfiguration.startBlock <= block.number,
            "Quest: This quest is not started yet"
        );
        require(
            questConfiguration.endBlock >= block.number,
            "Quest: This quest is already finished"
        );
        _;
    }

    modifier closeBlockRange(uint256 _questId) {
        Quest storage questConfiguration = quest[_questId];
        if (questConfiguration.valid)
            require(
                block.number <= questConfiguration.startBlock ||
                    block.number >= questConfiguration.endBlock,
                "Quest: Can not close quest if is not finished"
            );
        _;
    }

    constructor() {
        _questIds.increment();
    }

    event CreateQuest(
        address _tokenContractAddress,
        uint256 indexed questId,
        address operator,
        uint256[] outputTokenIds
    );

    function create(
        address _tokenContractAddress,
        uint256 _totalNumberOfQuests,
        uint256[] memory _inputTokenIds,
        uint256[] memory _outputTokenIds,
        uint256[] memory _inputTokenQuantities,
        uint256[] memory _outputTokenQuantities,
        bool _multipleParticipation,
        uint256 _startBlock,
        uint256 _endBlock,
        bytes calldata _data
    ) external nonReentrant {
        require(
            checkIdsValidity(_inputTokenIds),
            "Phoenix: input tokenId must be greater than 0"
        );

        require(
            checkIdsValidity(_outputTokenIds),
            "Phoenix: output tokenId must be greater than 0"
        );

        require(
            _startBlock < _endBlock,
            "Phoenix: startBlock must be lower than endBlock"
        );

        require(
            _startBlock >= 0 && _endBlock >= 0,
            "Phoenix: defined blocks have to be positive numbers"
        );

        require(
            chackTokenBalancesValidity(
                _tokenContractAddress,
                _totalNumberOfQuests,
                _outputTokenIds,
                _outputTokenQuantities,
                msg.sender
            ),
            "Phoenix: Insufficient token balance on one of output tokens"
        );

        distributeTokensOnCreate(
            _tokenContractAddress,
            _totalNumberOfQuests,
            _outputTokenIds,
            _outputTokenQuantities,
            msg.sender,
            _data
        );

        Quest memory questConfiguration = Quest(
            _questIds.current(),
            _tokenContractAddress,
            _totalNumberOfQuests,
            0,
            _inputTokenIds,
            _outputTokenIds,
            _inputTokenQuantities,
            _outputTokenQuantities,
            msg.sender,
            _multipleParticipation,
            _startBlock,
            _endBlock,
            true
        );

        quest[_questIds.current()] = questConfiguration;
        createdQuestIds.push(_questIds.current());

        emit CreateQuest(
            _tokenContractAddress,
            _questIds.current(),
            msg.sender,
            _outputTokenIds
        );

        _questIds.increment();
    }

    function checkIdsValidity(
        uint256[] memory ids
    ) private pure returns (bool) {
        bool isValid = true;
        for (uint256 index = 0; index < ids.length; index++) {
            if (ids[index] <= 0) isValid = false;
        }
        return isValid;
    }

    function chackTokenBalancesValidity(
        address _tokenContractAddress,
        uint256 _numberOfQuests,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenQuantities,
        address _operator
    ) private view returns (bool) {
        bool isValid = true;
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            if (
                IERC1155(_tokenContractAddress).balanceOf(
                    _operator,
                    _tokenIds[index]
                ) < _tokenQuantities[index].mul(_numberOfQuests)
            ) isValid = false;
        }
        return isValid;
    }

    function distributeTokensOnCreate(
        address _tokenContractAddress,
        uint256 _totalNumberOfQuests,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenQuantities,
        address _operator,
        bytes memory _data
    ) private {
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            IERC1155(_tokenContractAddress).safeTransferFrom(
                _operator,
                address(this),
                _tokenIds[index],
                _tokenQuantities[index].mul(_totalNumberOfQuests),
                _data
            );
        }
    }

    function completeQuest(
        uint256 _questId,
        bytes memory _data
    ) external nonReentrant completeBlockRange(_questId) {
        Quest storage questConfiguration = quest[_questId];

        require(
            chackTokenBalancesValidity(
                questConfiguration.tokenContractAddress,
                1,
                questConfiguration.inputTokenIds,
                questConfiguration.inputTokenQuantities,
                msg.sender
            ),
            "Phoenix: Insufficient token balance on one of input tokens"
        );

        require(
            questConfiguration.totalNumberOfQuests !=
                questConfiguration.numberOfQuestsCompleted,
            "Quest: Quest is already completed"
        );

        if (
            walletQuestParticipation[questConfiguration.questId][msg.sender] &&
            !questConfiguration.multipleParticipation
        ) {
            revert("Quest: Can not complete this quest multiple times");
        }

        // Sending output tokens to quest completor
        distributeTokensOnComplete(
            questConfiguration.tokenContractAddress,
            1,
            questConfiguration.outputTokenIds,
            questConfiguration.outputTokenQuantity,
            address(this),
            msg.sender,
            _data
        );

        // Burning received tokens to dead address
        distributeTokensOnComplete(
            questConfiguration.tokenContractAddress,
            1,
            questConfiguration.inputTokenIds,
            questConfiguration.inputTokenQuantities,
            msg.sender,
            deadContract,
            _data
        );

        questConfiguration.numberOfQuestsCompleted++;
        walletQuestParticipation[questConfiguration.questId][msg.sender] = true;
    }

    function closeQuest(
        uint256 _questId,
        bytes memory _data
    ) external closeBlockRange(_questId) {
        Quest storage questConfiguration = quest[_questId];

        require(
            questConfiguration.operator == msg.sender,
            "Quest: Action forbiden for nonoperator"
        );

        require(
            questConfiguration.valid,
            "Quest: This quest is already closed"
        );

        distributeTokensOnComplete(
            questConfiguration.tokenContractAddress,
            questConfiguration.totalNumberOfQuests.sub(
                questConfiguration.numberOfQuestsCompleted
            ),
            questConfiguration.outputTokenIds,
            questConfiguration.outputTokenQuantity,
            address(this),
            msg.sender,
            _data
        );

        questConfiguration.valid = false;
    }

    function distributeTokensOnComplete(
        address _tokenContractAddress,
        uint256 _numberOfQuests,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenQuantities,
        address _sender,
        address _receiver,
        bytes memory _data
    ) private {
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            if (_tokenQuantities[index].mul(_numberOfQuests) > 0)
                IERC1155(_tokenContractAddress).safeTransferFrom(
                    _sender,
                    _receiver,
                    _tokenIds[index],
                    _tokenQuantities[index].mul(_numberOfQuests),
                    _data
                );
        }
    }

    function getAllAvailableQuests() public view returns (Quest[] memory) {
        Quest[] memory availableQuestsList = new Quest[](
            createdQuestIds.length
        );
        for (uint256 i = 0; i < createdQuestIds.length; i++) {
            availableQuestsList[i] = quest[createdQuestIds[i]];
        }
        return availableQuestsList;
    }

    function getQuest(uint256 _questId) private view returns (Quest memory) {
        return quest[_questId];
    }

    function getQuestById(
        uint256 _questId
    )
        public
        view
        returns (
            uint256 questId,
            address tokenContractAddress,
            uint256 totalNumberOfQuests,
            uint256 numberOfQuestsCompleted,
            uint256[] memory inputTokenIds,
            uint256[] memory outputTokenIds,
            uint256[] memory inputTokenQuantities,
            uint256[] memory outputTokenQuantity,
            address operator,
            bool multipleParticipation,
            uint256 startBlock,
            uint256 endBlock,
            bool valid
        )
    {
        Quest memory questConfig = getQuest(_questId);
        return (
            questConfig.questId,
            questConfig.tokenContractAddress,
            questConfig.totalNumberOfQuests,
            questConfig.numberOfQuestsCompleted,
            questConfig.inputTokenIds,
            questConfig.outputTokenIds,
            questConfig.inputTokenQuantities,
            questConfig.outputTokenQuantity,
            questConfig.operator,
            questConfig.multipleParticipation,
            questConfig.startBlock,
            questConfig.endBlock,
            questConfig.valid
        );
    }
}