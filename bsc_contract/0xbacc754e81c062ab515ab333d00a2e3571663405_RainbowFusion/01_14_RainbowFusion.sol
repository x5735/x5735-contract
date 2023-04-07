import "../../utility-polymon-tracker/IUtilityPolymonTracker.sol";
import "../../IERC20Burnable.sol";
import "../../collection/MintableCollection.sol";
import "../../common/interfaces/IRewardable.sol";
import "../../common/interfaces/ITransferFromAndBurnFrom.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RainbowFusion is Initializable, OwnableUpgradeable, PausableUpgradeable {
    struct RainbowData {
        string typeString;
        uint256[] originIds;
    }

    IUtilityPolymonTracker public utilityPolymonTracker;
    IERC20Burnable public rainbowToken;
    IRewardable public fusionPortalStaking;
    MintableCollection public collection;
    mapping(uint256 => RainbowData) private _rainbowData;
    uint256 public currentId;
    uint256 public requiredPMONToken;
    uint256 public requiredRainbowToken;

    address public trustedSigner;

    address public rewardAddress;
    ITransferFrom public pmonToken;

    event FuseRainbow(address indexed owner, uint256 indexed tokenId, string typeString, uint256 timestamp, uint256[] burnedIds);

    function initialize(
        IUtilityPolymonTracker _utilityPolymonTracker,
        IERC20Burnable _rainbowToken,
        IRewardable _fusionPortalStaking,
        MintableCollection _collection,
        uint256 _currentId,
        uint256 _requiredPMONToken,
        uint256 _requiredRainbowToken,
        address _trustedSigner,
        address _rewardAddress,
        ITransferFrom _pmonToken
    ) public initializer {
        utilityPolymonTracker = _utilityPolymonTracker;
        rainbowToken = _rainbowToken;
        fusionPortalStaking = _fusionPortalStaking;
        collection = _collection;
        currentId = _currentId;
        requiredPMONToken = _requiredPMONToken;
        requiredRainbowToken = _requiredRainbowToken;
        trustedSigner = _trustedSigner;
        rewardAddress = _rewardAddress;
        pmonToken = _pmonToken;

        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function setUtilityPolymonTracker(IUtilityPolymonTracker _utilityPolymonTracker) external onlyOwner {
        utilityPolymonTracker = _utilityPolymonTracker;
    }

    function setRainbowToken(IERC20Burnable _rainbowToken) external onlyOwner {
        rainbowToken = _rainbowToken;
    }

    function setFusionPortalStaking(IRewardable _fusionPortalStaking) external onlyOwner {
        fusionPortalStaking = _fusionPortalStaking;
    }

    function setCollection(MintableCollection _collection) external onlyOwner {
        collection = _collection;
    }

    function setCurrentId(uint256 _currentId) external onlyOwner {
        currentId = _currentId;
    }

    function setRequiredPMONToken(uint256 _requiredPMONToken) external onlyOwner {
        requiredPMONToken = _requiredPMONToken;
    }

    function setRequiredRainbowToken(uint256 _requiredRainbowToken) external onlyOwner {
        requiredRainbowToken = _requiredRainbowToken;
    }

    function setTrustedSigner(address _trustedSigner) external onlyOwner {
        trustedSigner = _trustedSigner;
    }

    function setRewardAddress(address _rewardAddress) external onlyOwner {
        rewardAddress = _rewardAddress;
    }

    function setPmonToken(ITransferFrom _pmonToken) external onlyOwner {
        pmonToken = _pmonToken;
    }

    function rainbowData(uint256 id) external view returns (RainbowData memory data) {
        return _rainbowData[id];
    }

    function rainbowDataList(uint256[] calldata ids) external view returns (RainbowData[] memory) {
        RainbowData[] memory list = new RainbowData[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            list[i] = _rainbowData[ids[i]];
        }
        return list;
    }

    function fuse(
        IUtilityPolymonTracker.SoftMintedData[] memory softMinted,
        IUtilityPolymonTracker.SoftMintedDataOld[] memory softMintedOld,
        uint256[] memory hardMinted,
        string memory typeString,
        bytes memory signature
    ) external whenNotPaused {
        uint256 numberOfIds = softMinted.length + softMintedOld.length + hardMinted.length;

        if (numberOfIds < 5 || numberOfIds > 6) revert("Invalid burn count");

        uint256[] memory idList = new uint256[](numberOfIds);
        uint256 counter;
        // burn soft minted tokens
        for (uint256 i = 0; i < softMinted.length; i++) {
            require(utilityPolymonTracker.isOwnerSoftMinted(msg.sender, softMinted[i]), "Invalid soft minted token ID");
            utilityPolymonTracker.burnToken(msg.sender, softMinted[i].id, false);
            idList[counter] = softMinted[i].id;
            counter++;
        }
        // burn old soft minted tokens
        for (uint256 i = 0; i < softMintedOld.length; i++) {
            require(utilityPolymonTracker.isOwnerSoftMintedOld(msg.sender, softMintedOld[i]), "Invalid soft minted (old) token ID");
            utilityPolymonTracker.burnToken(msg.sender, softMintedOld[i].id, false);
            idList[counter] = softMintedOld[i].id;
            counter++;
        }
        // burn hard minted tokens
        for (uint256 i = 0; i < hardMinted.length; i++) {
            require(utilityPolymonTracker.isOwnerHardMinted(msg.sender, hardMinted[i]), "Invalid hard minted token ID");
            utilityPolymonTracker.burnToken(msg.sender, hardMinted[i], true);
            idList[counter] = hardMinted[i];
            counter++;
        }

        require(signatureVerification(msg.sender, typeString, idList, signature), "Invalid signer or signature");

        collection.mint(msg.sender, currentId);

        _rainbowData[currentId] = RainbowData(typeString, idList);

        if (rewardAddress != address(0) && address(pmonToken) != address(0)) {
            pmonToken.transferFrom(msg.sender, rewardAddress, requiredPMONToken);
        } else {
            IERC20Upgradeable[] memory portalRewardTokens = fusionPortalStaking.getRewardTokens();
            uint256[] memory rewards = new uint256[](portalRewardTokens.length);
            for (uint256 i = 0; i < portalRewardTokens.length; i++) {
                if (address(pmonToken) == address(portalRewardTokens[i])) {
                    rewards[i] = requiredPMONToken;
                }
            }
            fusionPortalStaking.addRewards(msg.sender, rewards);
        }
        rainbowToken.burnFrom(msg.sender, requiredRainbowToken);

        emit FuseRainbow(msg.sender, currentId, typeString, block.timestamp, idList);
        currentId++;
    }

    function splitSignature(bytes memory signature)
        private
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        bytes32 sigR;
        bytes32 sigS;
        uint8 sigV;
        assembly {
            sigR := mload(add(signature, 32))
            sigS := mload(add(signature, 64))
            sigV := byte(0, mload(add(signature, 96)))
        }
        return (sigV, sigR, sigS);
    }

    /**
     * Check the signature of the harvest function.
     */
    function signatureVerification(
        address sender,
        string memory typeString,
        uint256[] memory idList,
        bytes memory signature
    ) private returns (bool) {
        bytes32 sigR;
        bytes32 sigS;
        uint8 sigV;
        (sigV, sigR, sigS) = splitSignature(signature);
        bytes32 msg = keccak256(abi.encodePacked(sender, typeString, idList));
        return trustedSigner == ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msg)), sigV, sigR, sigS);
    }
}