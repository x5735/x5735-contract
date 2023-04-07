// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import "./EconBaseContract.sol";
import "./Econ721Enumerable.sol";

contract Econ721Signature is EconBaseContract, Econ721Enumerable, ERC721HolderUpgradeable {
    using ECDSA for bytes32;

    mapping(bytes32 => bool) private _handled; // withdrawId

    event Deposited(address user, address contractAddress, uint256 tokenId);
    event Withdrawn(bytes32 withdrawId, address user, address contractAddress, uint256 tokenId);
    event WithdrawFailed(bytes32 withdrawId, address user, address contractAddress, uint256 tokenId);

    function initialize() public virtual initializer {
        __BaseContract_init();
    }

    function deposit(address _contractAddress, uint256 _tokenId) external {
        require(
            IERC721(_contractAddress).isApprovedForAll(_msgSender(), address(this)) ||
                IERC721(_contractAddress).getApproved(_tokenId) == address(this),
            "Error: AssetNotAllowed"
        );

        IERC721(_contractAddress).safeTransferFrom(_msgSender(), address(this), _tokenId);
    }

    function getSignedMessageHash(
        address _contractAddress,
        uint256 _tokenId,
        address _to,
        uint256 _expiryTime,
        bytes32 _withdrawId
    ) public view returns (bytes32) {
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), _contractAddress, _tokenId, _to, _expiryTime));
        bytes32 signedMessageHash = keccak256(abi.encodePacked(messageHash, _withdrawId));

        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", signedMessageHash));
    }

    function withdraw(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _expiryTime,
        bytes32 _withdrawId,
        bytes memory signature
    ) external nonReentrant whenNotPaused whenNotMaintain {
        require(_owners[_contractAddress][_tokenId] == _msgSender(), "Error: NotOwner");

        require(!_handled[_withdrawId]);

        bytes32 ethSignedMessageHash = getSignedMessageHash(
            _contractAddress,
            _tokenId,
            _msgSender(),
            _expiryTime,
            _withdrawId
        );
        (address recovered, ) = ethSignedMessageHash.tryRecover(signature);

        require(recovered == signer, "Error: InvalidSignature");
        require(block.timestamp <= _expiryTime, "Error: ExpiriedTime");

        _handled[_withdrawId] = true;

        try IERC721(_contractAddress).safeTransferFrom(address(this), _msgSender(), _tokenId) {
            _removeTokenFromOwnerEnumeration(_contractAddress, _msgSender(), _tokenId);
            _removeTokenFromAllTokensEnumeration(_contractAddress, _tokenId);
            _balances[_contractAddress][_msgSender()] -= 1;
            delete _owners[_contractAddress][_tokenId];
            emit Withdrawn(_withdrawId, _msgSender(), _contractAddress, _tokenId);
        } catch {
            emit WithdrawFailed(_withdrawId, _msgSender(), _contractAddress, _tokenId);
        }
    }

    function withdrawERC721(
        address _to,
        address _contractAddress,
        uint256 _tokenId
    ) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_owners[_contractAddress][_tokenId] == address(0), "Error: AssetIsUserDeposit");

        IERC721(_contractAddress).safeTransferFrom(address(this), _to, _tokenId);
    }

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) public virtual override nonReentrant whenNotPaused whenNotMaintain returns (bytes4) {
        require(_whitelistContract[_msgSender()], "Error: AssetContractNotAllowed");

        _addTokenToAllTokensEnumeration(_msgSender(), _tokenId);
        _addTokenToOwnerEnumeration(_msgSender(), _from, _tokenId);
        _balances[_msgSender()][_from] += 1;
        _owners[_msgSender()][_tokenId] = _from;

        emit Deposited(_from, _msgSender(), _tokenId);

        return this.onERC721Received.selector;
    }

    function cancelWithdraw(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _expiryTime,
        bytes32 _withdrawId,
        bytes memory signature
    ) external {
        require(
            _owners[_contractAddress][_tokenId] == _msgSender() || hasRole(CONFIG_ROLE, _msgSender()),
            "Error: NotPermission"
        );

        require(!_handled[_withdrawId]);

        bytes32 ethSignedMessageHash = getSignedMessageHash(
            _contractAddress,
            _tokenId,
            _msgSender(),
            _expiryTime,
            _withdrawId
        );
        (address recovered, ) = ethSignedMessageHash.tryRecover(signature);

        require(recovered == signer, "Error: InvalidSignature");
        _handled[_withdrawId] = true;

        emit WithdrawFailed(_withdrawId, _msgSender(), _contractAddress, _tokenId);
    }
}