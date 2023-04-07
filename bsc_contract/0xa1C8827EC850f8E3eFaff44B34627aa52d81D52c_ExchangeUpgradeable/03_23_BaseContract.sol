// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";

contract BaseContract is
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IERC721ReceiverUpgradeable,
    ERC1155ReceiverUpgradeable
{
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address payable public treasury;

    mapping(address => bool) private _whitelistPaymentToken;
    mapping(address => bool) private _whitelistNFTContractAddress;
    // whitelist NFT contract address => isERC1155
    mapping(address => bool) private _isERC1155;

    uint256 public feePercent;

    event PaymentTokenWhitelistChanged(address paymentToken, bool allowance);
    event NFTContractAddressWhitelistChanged(address contractAddress, bool isERC1155, bool allowance);

    event FeePercentChanged(uint256 newFeePercent);

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: ADMIN role required");
        _;
    }

    modifier onlyConfigRole() {
        require(hasRole(CONFIG_ROLE, _msgSender()), "Error: CONFIG role required");
        _;
    }

    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, _msgSender()), "Error: PAUSER role required");
        _;
    }

    function __BaseContract_init(address multisigAddress_, address treasury_) internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, multisigAddress_);
        _setupRole(CONFIG_ROLE, multisigAddress_);
        _setupRole(PAUSER_ROLE, multisigAddress_);

        treasury = payable(treasury_);
        feePercent = 0 ether;
    }

    function setTreasury(address newTreasury) public onlyAdmin whenPaused {
        require(treasury != newTreasury);
        treasury = payable(newTreasury);
    }

    function setWhitelistPaymentToken(address paymentToken, bool allowance) public onlyConfigRole {
        require(_whitelistPaymentToken[paymentToken] != allowance);

        _whitelistPaymentToken[paymentToken] = allowance;

        emit PaymentTokenWhitelistChanged(paymentToken, allowance);
    }

    function setWhitelistNFTContractAddress(
        address contractAddress,
        bool isERC1155,
        bool allowance
    ) public onlyConfigRole {
        require(_whitelistNFTContractAddress[contractAddress] != allowance || _isERC1155[contractAddress] != isERC1155);

        _whitelistNFTContractAddress[contractAddress] = allowance;
        _isERC1155[contractAddress] = isERC1155;

        emit NFTContractAddressWhitelistChanged(contractAddress, isERC1155, allowance);
    }

    function setFeePercent(uint256 newFeePercent) public onlyConfigRole whenPaused {
        require(feePercent != newFeePercent);
        feePercent = newFeePercent;
        emit FeePercentChanged(newFeePercent);
    }

    function pause() public onlyPauser {
        _pause();
    }

    function unpause() public onlyPauser {
        _unpause();
    }

    function withdraw(
        address payable to,
        address token,
        uint256 amount
    ) public nonReentrant onlyAdmin {
        if (token == address(0)) {
            require(address(this).balance >= amount, "Error: Exceeds balance");
            require(to.send(amount), "Error: Transfer failed");
        } else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "Error: Exceeds balance");
            require(IERC20(token).transfer(to, amount), "Error: Transfer failed");
        }
    }

    function _transferAsset(
        address contractAddress,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) internal returns (uint256) {
        if (_isERC1155[contractAddress]) {
            IERC1155(contractAddress).safeTransferFrom(from, to, tokenId, amount, data);
            return amount;
        } else {
            IERC721(contractAddress).safeTransferFrom(from, to, tokenId, data);
            return 1;
        }
    }

    function _checkWhitelistPaymentToken(address paymentToken) internal view {
        require(_whitelistPaymentToken[paymentToken], "Error: Payment token not allowed");
    }

    function _checkWhitelistNFTContract(address contractAddress) internal view {
        require(_whitelistNFTContractAddress[contractAddress], "Error: NFT contract not allowed");
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        require(operator == address(this), "Error: Not accept");
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        require(operator == address(this), "Error: Not accept");
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        revert("Error: Not accept");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}