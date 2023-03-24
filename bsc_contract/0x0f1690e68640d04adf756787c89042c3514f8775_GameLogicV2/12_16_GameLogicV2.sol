// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libraries/BotanStruct.sol";
import "../libraries/LandStruct.sol";
import "../nft/IBotanNFT.sol";
import "../nft/ILandNFT.sol";
import "../role/IRole.sol";
import "../role/IBlackList.sol";
import "../gene/IGeneScience.sol";

contract GameLogicV2 {
    event SetContractEvent(uint256 _type, address _contract);
    event SetContractOwnerEvent(address _owner);
    event SetUnboxSecondsEvent(uint64 _val);
    event SetGrowSecondsEvent(uint64 _val);
    event SetSecondsPerBlockEvent(uint64 _val);
    event SetMaxBreedTimesEvent(uint8 _cVal, uint8 _rVal, uint8 _srVal, uint8 _ssrVal);
    event BurnBotanEvent(uint256 _val);
    event BurnLandEvent(uint256 _val);
    event AdminWithdrawEvent(
        address indexed _tokenAddr,
        uint256 indexed _orderId,
        address _from,
        address indexed _to,
        uint256 _amountOrTokenId
    );
    event UserWithdrawEvent(
        address indexed _tokenAddr,
        uint256 indexed _orderId,
        address _from,
        address indexed _to,
        uint256 _amountOrTokenId
    );
    event SetWithdrawAddressEvent(address _address);
    event OrderPaymentEvent(
        address indexed _tokenAddr,
        uint256 indexed _orderId,
        address indexed _userAddress,
        uint256 _amount
    );
    event SetSignerEvent(address _signer);
    event SetVersionEvent(string _version);

    struct PayInfo {
        address from;
        address to;
        address tokenAddress;
        uint256 amount;
    }

    IBotanNFT internal botanNFT;
    ILandNFT internal landNFT;
    IRole internal roleContract;
    IBlackList internal blackListContract;
    IGeneScience internal geneScienceContract;

    uint64 internal secondsPerBlock;
    // grow time
    uint64 internal growSeconds;
    uint64 internal growBlocks;

    uint8[5] internal maxBreedTimes;

    address internal signer;
    address internal owner;
    mapping(bytes => bool) internal signMap;

    address internal withdrawAddr;

    string internal version = "pc_gl_v2";

    constructor() {
        owner = msg.sender;
        secondsPerBlock = 3;
        growSeconds = 600 seconds;
        growBlocks = growSeconds / secondsPerBlock;
        maxBreedTimes = [0, 7, 6, 5, 3];
        withdrawAddr = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
        emit SetContractOwnerEvent(_newOwner);
    }

    modifier onlyCFO() {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCFO(msg.sender), "Only CFO can call this function");
        _;
    }

    function setSigner(address _signer) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        signer = _signer;
        emit SetSignerEvent(_signer);
    }

    function setVersion(string calldata _version) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        version = _version;
        emit SetVersionEvent(_version);
    }

    function setBotanNFTContract(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        botanNFT = IBotanNFT(_address);
        emit SetContractEvent(0, _address);
    }

    function setLandNFTContract(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        landNFT = ILandNFT(_address);
        emit SetContractEvent(1, _address);
    }

    function setRoleContract(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        roleContract = IRole(_address);
        emit SetContractEvent(2, _address);
    }

    function setBlackListContract(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        blackListContract = IBlackList(_address);
        emit SetContractEvent(3, _address);
    }

    function setGeneScienceContract(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        geneScienceContract = IGeneScience(_address);
        emit SetContractEvent(4, _address);
    }

    function setWithdrawAddr(address _address) external {
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCEO(msg.sender)),
            "Permission denied"
        );
        withdrawAddr = _address;
        emit SetWithdrawAddressEvent(_address);
    }

    function setGrowSeconds(uint64 _val) external {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCEO(msg.sender), "Permission denied");
        growSeconds = _val;
        growBlocks = growSeconds / secondsPerBlock;
        emit SetGrowSecondsEvent(_val);
    }

    function setSecondsPerBlock(uint64 _val) external {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCEO(msg.sender), "Permission denied");
        secondsPerBlock = _val;
        growBlocks = growSeconds / secondsPerBlock;
        emit SetSecondsPerBlockEvent(_val);
    }

    function setMaxBreedTimes(uint8[5] calldata _val) external {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCEO(msg.sender), "Permission denied");
        maxBreedTimes = _val;
        emit SetMaxBreedTimesEvent(_val[1], _val[2], _val[3], _val[4]);
    }

    function doGrow(
        uint256 _tokenId,
        BotanStruct.Botan memory _newPlantData,
        uint256 _tx
    ) internal returns (BotanStruct.Botan memory) {
        require(address(botanNFT) != address(0), "BotanNFT contract isn't set");
        require(botanNFT.exists(_tokenId), "Token is not minted");
        BotanStruct.Botan memory _seed = botanNFT.getPlantDataByLogic(_tokenId);
        require(_seed.phase == BotanStruct.BotanPhase.Seed, "This is not a seed");
        require((_seed.time + growSeconds) < block.timestamp, "Time is not reached");
        _seed.rarity = _newPlantData.rarity;
        _seed.category = _newPlantData.category;
        botanNFT.growByLogic(_tokenId, _seed, _tx);
        return _newPlantData;
    }

    function grow(uint256 _tokenId, uint256 _tx) external returns (BotanStruct.Botan memory) {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(address(geneScienceContract) != address(0), "GeneScience Contract contract isn't set");
        require(roleContract.isCXO(msg.sender), "Permission denied");
        BotanStruct.Botan memory seed = botanNFT.getPlantDataByLogic(_tokenId);
        BotanStruct.Botan memory dad = botanNFT.getPlantDataByLogic(seed.dadId);
        BotanStruct.Botan memory mom = botanNFT.getPlantDataByLogic(seed.momId);
        BotanStruct.Botan memory _newPlantData = geneScienceContract.grow(seed, dad, mom);
        return doGrow(_tokenId, _newPlantData, _tx);
    }

    function growByPlantData(
        uint256 _tokenId,
        BotanStruct.Botan calldata _newPlantData,
        uint256 _tx
    ) external returns (BotanStruct.Botan memory) {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCXO(msg.sender), "Permission denied");
        BotanStruct.Botan memory _seed = botanNFT.getPlantDataByLogic(_tokenId);
        _seed.rarity = _newPlantData.rarity;
        _seed.category = _newPlantData.category;
        return doGrow(_tokenId, _seed, _tx);
    }

    function growByPlantDataWithSign(
        uint256 _tokenId,
        BotanStruct.Botan calldata _newPlantData,
        uint256 _tx,
        bytes memory _sign
    ) external returns (BotanStruct.Botan memory) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    "pc_gl_v1",
                    _tokenId,
                    _newPlantData.category,
                    _newPlantData.rarity,
                    _newPlantData.breedTimes,
                    _newPlantData.phase,
                    _newPlantData.dadId,
                    _newPlantData.momId,
                    _tx,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        return doGrow(_tokenId, _newPlantData, _tx);
    }

    function breed(
        address _owner,
        uint256 _dadId,
        uint256 _momId,
        BotanStruct.BotanRarity _rarity,
        uint256 _tx,
        bool _safe
    ) external returns (uint256) {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCXO(msg.sender), "Permission denied");
        return doBreed(_owner, _dadId, _momId, _rarity, _tx, _safe);
    }

    function breedWithSign(
        address _owner,
        uint256 _dadId,
        uint256 _momId,
        BotanStruct.BotanRarity _rarity,
        uint256 _tx,
        bool _safe,
        bytes memory _sign
    ) external returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked("pc_gl_v1", _owner, _dadId, _momId, _rarity, _tx, _safe, block.chainid))
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        return doBreed(_owner, _dadId, _momId, _rarity, _tx, _safe);
    }

    function doBreed(
        address _owner,
        uint256 _dadId,
        uint256 _momId,
        BotanStruct.BotanRarity _rarity,
        uint256 _tx,
        bool _safe
    ) internal returns (uint256) {
        require(address(botanNFT) != address(0), "BotanNFT contract isn't set");
        require(botanNFT.exists(_dadId), "Dad is not minted");
        require(botanNFT.exists(_momId), "Mom is not minted");
        BotanStruct.Botan memory dad = botanNFT.getPlantDataByLogic(_dadId);
        BotanStruct.Botan memory mom = botanNFT.getPlantDataByLogic(_momId);
        require(
            ((mom.momId == 0 || dad.dadId == 0) ||
                // Or their parents are not same.There are not brother
                ((mom.dadId != dad.dadId) &&
                    (mom.dadId != dad.momId) &&
                    (mom.momId != dad.momId) &&
                    (mom.momId != dad.dadId))) &&
                // Their parents can not be father and son
                ((_momId != dad.momId && _momId != dad.dadId) && (_dadId != mom.momId && _dadId != mom.dadId)),
            "Inbreeding is prohibited."
        );
        uint8 mombt = maxBreedTimes[uint8(mom.rarity)];
        uint8 dadbt = maxBreedTimes[uint8(dad.rarity)];
        require((mom.breedTimes < mombt) && (dad.breedTimes < dadbt), "Breeding limit exceeded.");
        return
            botanNFT.breedByLogic(_owner, _dadId, _momId, _rarity, uint64(block.number + growBlocks - 1), _tx, _safe);
    }

    function mintLand(
        address _owner,
        LandStruct.Land calldata _landData,
        uint256 _tx,
        bool _safe
    ) external returns (uint256) {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCXO(msg.sender), "Permission denied");
        return landNFT.mintLandByLogic(_owner, _landData, _tx, _safe);
    }

    function mintLandWithSign(
        address _owner,
        LandStruct.Land calldata _landData,
        uint256 _tx,
        bool _safe,
        bytes memory _sign
    ) external returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    "pc_gl_v1",
                    _owner,
                    _landData.category,
                    _landData.rarity,
                    _landData.time,
                    _tx,
                    _safe,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        return landNFT.mintLandByLogic(_owner, _landData, _tx, _safe);
    }

    function mintSeedOrPlant(
        address _owner,
        BotanStruct.Botan calldata _plantData,
        uint256 _tx,
        bool _safe
    ) external returns (uint256) {
        require(address(roleContract) != address(0), "Role contract isn't set");
        require(roleContract.isCXO(msg.sender), "Permission denied");
        return botanNFT.mintSeedOrPlantByLogic(_owner, _plantData, _tx, _safe);
    }

    function mintSeedOrPlantWithSign(
        address _owner,
        BotanStruct.Botan calldata _plantData,
        uint256 _tx,
        bool _safe,
        bytes memory _sign
    ) external returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    "pc_gl_v1",
                    _owner,
                    _plantData.category,
                    _plantData.rarity,
                    _plantData.breedTimes,
                    _plantData.phase,
                    _plantData.dadId,
                    _plantData.momId,
                    _tx,
                    _safe,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        return botanNFT.mintSeedOrPlantByLogic(_owner, _plantData, _tx, _safe);
    }

    function growByPlantDataWithSignV2(
        uint256 _tokenId,
        BotanStruct.Botan calldata _newPlantData,
        uint256 _tx,
        PayInfo calldata _payInfo,
        bytes memory _sign
    ) external payable virtual returns (BotanStruct.Botan memory) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes memory _encodedPayInfo = abi.encodePacked(
            _payInfo.from,
            _payInfo.to,
            _payInfo.tokenAddress,
            _payInfo.amount
        );
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    version,
                    _tokenId,
                    _newPlantData.category,
                    _newPlantData.rarity,
                    _newPlantData.breedTimes,
                    _newPlantData.phase,
                    _tx,
                    _encodedPayInfo,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        if (_payInfo.amount > 0) {
            payTokenV2(_payInfo.tokenAddress, _payInfo.to, _payInfo.amount, _tx);
        }
        return doGrow(_tokenId, _newPlantData, _tx);
    }

    function breedWithSignV2(
        address _owner,
        uint256 _dadId,
        uint256 _momId,
        BotanStruct.BotanRarity _rarity,
        uint256 _tx,
        bool _safe,
        PayInfo calldata _payInfo,
        bytes memory _sign
    ) external payable returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes memory _encodedPayInfo = abi.encodePacked(
            _payInfo.from,
            _payInfo.to,
            _payInfo.tokenAddress,
            _payInfo.amount
        );
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(version, _owner, _rarity, _tx, _safe, _encodedPayInfo, block.chainid))
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        if (_payInfo.amount > 0) {
            payTokenV2(_payInfo.tokenAddress, _payInfo.to, _payInfo.amount, _tx);
        }
        return doBreed(_owner, _dadId, _momId, _rarity, _tx, _safe);
    }

    function mintLandWithSignV2(
        address _owner,
        LandStruct.Land calldata _landData,
        uint256 _tx,
        bool _safe,
        PayInfo calldata _payInfo,
        bytes memory _sign
    ) external payable returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes memory _encodedPayInfo = abi.encodePacked(
            _payInfo.from,
            _payInfo.to,
            _payInfo.tokenAddress,
            _payInfo.amount
        );
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    version,
                    _owner,
                    _landData.category,
                    _landData.rarity,
                    _landData.time,
                    _tx,
                    _safe,
                    _encodedPayInfo,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        if (_payInfo.amount > 0) {
            payTokenV2(_payInfo.tokenAddress, _payInfo.to, _payInfo.amount, _tx);
        }
        return landNFT.mintLandByLogic(_owner, _landData, _tx, _safe);
    }

    function mintSeedOrPlantWithSignV2(
        address _owner,
        BotanStruct.Botan calldata _plantData,
        uint256 _tx,
        bool _safe,
        PayInfo calldata _payInfo,
        bytes memory _sign
    ) external payable returns (uint256) {
        require(signMap[_sign] != true, "This signature already be used!");
        bytes memory _encodedPayInfo = abi.encodePacked(
            _payInfo.from,
            _payInfo.to,
            _payInfo.tokenAddress,
            _payInfo.amount
        );
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    version,
                    _owner,
                    _plantData.category,
                    _plantData.rarity,
                    _plantData.breedTimes,
                    _plantData.phase,
                    _tx,
                    _encodedPayInfo,
                    block.chainid
                )
            )
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        if (_payInfo.amount > 0) {
            payTokenV2(_payInfo.tokenAddress, _payInfo.to, _payInfo.amount, _tx);
        }
        return botanNFT.mintSeedOrPlantByLogic(_owner, _plantData, _tx, _safe);
    }

    function payTokenV2(address _tokenAddr, address _to, uint256 _amount, uint256 _orderId) public payable virtual {
        require(_amount > 0, "You need pay some token");
        require(address(blackListContract) != address(0), "BlackList contract isn't set");
        require(blackListContract.notInBlackList(msg.sender), "You are on the blacklist");
        if (_tokenAddr == address(0)) {
            payMainTokenV2(_amount, _orderId);
        } else {
            payErc20TokenV2(_tokenAddr, _to, _amount, _orderId);
        }
    }

    function payMainTokenV2(uint256 _amount, uint256 _orderId) public payable virtual {
        require(msg.value >= _amount, "You don't pay enough main token");
        emit OrderPaymentEvent(address(0), _orderId, msg.sender, _amount);
    }

    function payErc20TokenV2(address _tokenAddr, address _to, uint256 _amount, uint256 _orderId) internal virtual {
        IERC20 tokenContract = IERC20(_tokenAddr);
        uint256 allowance = tokenContract.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");
        tokenContract.transferFrom(msg.sender, _to, _amount);
        emit OrderPaymentEvent(_tokenAddr, _orderId, msg.sender, _amount);
    }

    function withdrawMainTokenV2ByAdmin(uint256 _orderId, uint256 _amount) public onlyCFO returns (bool) {
        require(_amount <= address(this).balance, "Not enough main token");
        // solhint-disable-next-line avoid-low-level-calls
        (bool ret /*bytes memory data*/, ) = withdrawAddr.call{ value: _amount }("");
        if (ret) {
            emit AdminWithdrawEvent(address(0), _orderId, address(this), withdrawAddr, _amount);
        } else {
            revert("Withdraw main token failed");
        }

        return ret;
    }

    function withdrawErc20TokenV2ByAdmin(
        address _tokenAddr,
        uint256 _orderId,
        uint256 _amount
    ) public onlyCFO returns (bool) {
        IERC20 tokenContract = IERC20(_tokenAddr);
        require(_amount <= tokenContract.balanceOf(address(this)), "Not enough ERC20 token");
        bool ret = tokenContract.transfer(withdrawAddr, _amount);
        if (ret) {
            emit AdminWithdrawEvent(_tokenAddr, _orderId, address(this), withdrawAddr, _amount);
        } else {
            revert("Withdraw ERC20 token failed");
        }

        return ret;
    }

    function withdrawErc20TokenV2ByUser(
        address _tokenAddr,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _orderId,
        bytes memory _sign
    ) public returns (bool) {
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(version, _tokenAddr, _from, _to, _amount, _orderId, block.chainid))
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        IERC20 tokenContract = IERC20(_tokenAddr);
        tokenContract.transferFrom(_from, _to, _amount);
        emit UserWithdrawEvent(_tokenAddr, _orderId, _from, _to, _amount);
        return true;
    }

    function withdrawErc721TokenV2ByUser(
        address _tokenAddr,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _orderId,
        bytes memory _sign
    ) public returns (bool) {
        bytes32 _msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(version, _tokenAddr, _from, _to, _tokenId, _orderId, block.chainid))
        );
        address signerAddress = ECDSA.recover(_msgHash, _sign);
        require(signerAddress != address(0) && signerAddress == signer, "Invalid Signer!");
        signMap[_sign] = true;
        IERC721 tokenContract = IERC721(_tokenAddr);
        tokenContract.transferFrom(_from, _to, _tokenId);
        emit UserWithdrawEvent(_tokenAddr, _orderId, _from, _to, _tokenId);
        return true;
    }

    function burnBotan(uint256 _tokenId) external {
        require(address(botanNFT) != address(0), "BotanNFT contract isn't set");
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCXO(msg.sender)),
            "Permission denied"
        );
        botanNFT.burnByLogic(_tokenId);
        emit BurnBotanEvent(_tokenId);
    }

    function burnLand(uint256 _tokenId) external {
        require(address(landNFT) != address(0), "LandNFT contract isn't set");
        require(
            owner == msg.sender || (address(roleContract) != address(0) && roleContract.isCXO(msg.sender)),
            "Permission denied"
        );
        landNFT.burnByLogic(_tokenId);
        emit BurnLandEvent(_tokenId);
    }
}