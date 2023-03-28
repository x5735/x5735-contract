// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LittleRabbitNFTStaking is Ownable, ERC721Holder {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    struct StakingData {
        bool isStaked;
        address owner;
        uint256 stakedTime;
        uint256 claimedTime;
    }

    uint256 public rewardPerHourdPerNFT;
    uint256 public totalStakedNFT;
    uint256 public totalReward;

    IERC721 public nftAddress;
    IERC20 public tokenAddress;

    mapping(uint256 => StakingData) public stakedNFT;
    mapping(address => uint256) public unclaimedReward;
    mapping(address => EnumerableSet.UintSet) private _stakedListNFT;

    event Stake(
        uint256 indexed _tokenId,
        address indexed _nftAddress,
        address indexed _owner
    );
    event Unstake(
        uint256 indexed _tokenId,
        address indexed _nftAddress,
        address indexed _owner
    );
    event Claim(
        address indexed _nftAddress,
        address indexed _owner,
        uint256 indexed _amount
    );

    constructor(
        address _nftAddress,
        address _tokenAddress,
        uint256 _rewardPerHourdPerNFT
    ) {
        nftAddress = IERC721(_nftAddress);
        tokenAddress = IERC20(_tokenAddress);
        rewardPerHourdPerNFT = _rewardPerHourdPerNFT;
    }

    function stake(uint256 _tokenId) public {
        require(
            nftAddress.ownerOf(_tokenId) == msg.sender,
            "You are not the owner of this NFT"
        );
        require(
            !stakedNFT[_tokenId].isStaked,
            "This NFT is already in staking"
        );

        nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);
        stakedNFT[_tokenId].isStaked = true;
        stakedNFT[_tokenId].owner = msg.sender;
        stakedNFT[_tokenId].stakedTime = block.timestamp;
        _stakedListNFT[msg.sender].add(_tokenId);
        totalStakedNFT++;

        emit Stake(_tokenId, address(nftAddress), msg.sender);
    }

    function unstake(uint256 _tokenId) public {
        require(
            stakedNFT[_tokenId].owner == msg.sender,
            "You are not the owner of this NFT"
        );
        require(stakedNFT[_tokenId].isStaked, "This NFT is not in staking");
        uint256 _unclaimedReward = _calculateReward(_tokenId);

        nftAddress.safeTransferFrom(address(this), msg.sender, _tokenId);
        unclaimedReward[msg.sender] += _unclaimedReward;
        stakedNFT[_tokenId].isStaked = false;
        stakedNFT[_tokenId].owner = address(0);
        stakedNFT[_tokenId].stakedTime = 0;
        stakedNFT[_tokenId].claimedTime = 0;
        _stakedListNFT[msg.sender].remove(_tokenId);
        totalStakedNFT--;
        
        emit Unstake(_tokenId, address(nftAddress), msg.sender);
    }

    function claimReward() public {
        uint256[] memory _stakedList = _stakedListNFT[msg.sender].values();
        uint256 reward = getReward();
        tokenAddress.safeTransfer(msg.sender, reward);

        totalReward -= reward;
        unclaimedReward[msg.sender] = 0;
        for (uint256 i; i < _stakedList.length; i++) {
            stakedNFT[_stakedList[i]].claimedTime = block.timestamp;
        }

        emit Claim(address(nftAddress), msg.sender, reward);
    }

    function getReward() public view returns (uint256 reward) {
        uint256[] memory _stakedList = _stakedListNFT[msg.sender].values();
        reward = unclaimedReward[msg.sender];

        for (uint256 i; i < _stakedList.length; i++) {
            reward += _calculateReward(_stakedList[i]);
        }
    }

    function getStakedList(address _owner) public view returns (uint256[] memory, StakingData[] memory) {
        uint256[] memory _stakedList = _stakedListNFT[_owner].values();
        StakingData[] memory _stakedData = new StakingData[](_stakedList.length);

        for (uint256 i; i < _stakedList.length; i++) {
            _stakedData[i] = stakedNFT[_stakedList[i]];
        }

        return (_stakedList, _stakedData);
    }

    function _calculateReward(uint256 _tokenId)
        internal
        view
        returns (uint256 reward)
    {
        require(stakedNFT[_tokenId].isStaked, "This NFT is not in staking");
        StakingData memory data = stakedNFT[_tokenId];
        uint256 stakeDurationSecond;

        if (data.claimedTime > 0) {
            stakeDurationSecond = block.timestamp - data.claimedTime;
        } else {
            stakeDurationSecond = block.timestamp - data.stakedTime;
        }
        uint256 stakeDurationHour = stakeDurationSecond / 1 hours;
        reward = stakeDurationHour * rewardPerHourdPerNFT;
    }

    function setRewardPerHourdPerNFT(uint256 _rewardPerHourdPerNFT) public onlyOwner {
        rewardPerHourdPerNFT = _rewardPerHourdPerNFT;
    }

    function setNftAddress(address _nftAddress) public onlyOwner {
        nftAddress = IERC721(_nftAddress);
    }
    
    function setTokenAddress(address _tokenAddress) public onlyOwner {
        tokenAddress = IERC20(_tokenAddress);
    }

    function addReward(uint256 _addAmount) public onlyOwner {
        tokenAddress.safeTransferFrom(msg.sender, address(this), _addAmount);
        totalReward += _addAmount;
    }

    function withdrawToken(uint256 _amount) public onlyOwner {
        require(tokenAddress.balanceOf(address(this)) >= _amount, "Not enough token balance");
        tokenAddress.safeTransfer(msg.sender, _amount);
    }
}