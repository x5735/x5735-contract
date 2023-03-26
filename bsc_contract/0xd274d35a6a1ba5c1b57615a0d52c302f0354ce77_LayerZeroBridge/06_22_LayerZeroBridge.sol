// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

// Contracts
import { SafeTransferLib, ERC20 } from "solmate/utils/SafeTransferLib.sol";
import { NonBlockingLzApp } from "./lz_app/NonBlockingLzApp.sol";
import { UUPSUpgradeable } from "../../proxy/UUPSUpgradeable.sol";

// Interfaces
import { IUSX } from "../../common/interfaces/IUSX.sol";
import { IERC20 } from "../../common/interfaces/IERC20.sol";

contract LayerZeroBridge is NonBlockingLzApp, UUPSUpgradeable {
    // Private Constants: no SLOAD to save users gas
    uint256 private constant NO_EXTRA_GAS = 0;
    uint256 private constant FUNCTION_TYPE_SEND = 1;
    address private constant DEPLOYER = 0x4bb324aDef9f60D611D140Ef9407fdF5E026cE77;

    // Storage Variables: follow storage slot restrictions
    bool public useCustomAdapterParams;
    address public usx;

    // Events
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);

    function initialize(address _lzEndpoint, address _usx) public initializer {
        /// @dev No constructor, so initialize Ownable explicitly.
        require(msg.sender == DEPLOYER, "Invalid caller.");
        require(_lzEndpoint != address(0) && _usx != address(0), "Invalid parameter.");
        __Ownable_init();
        __NonBlockingLzApp_init_unchained(_lzEndpoint);
        usx = _usx;
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner { }

    function sendMessage(address payable _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        external
        payable
        returns (uint64 sequence)
    {
        require(msg.sender == usx, "Unauthorized.");

        _send(_from, _dstChainId, _toAddress, _amount, address(0), bytes(""));

        emit SendToChain(_dstChainId, _from, _toAddress, _amount);

        sequence = 0;
    }

    function _send(
        address payable _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal virtual {
        // Cast encoded _toAddress to uint256
        uint256 toAddressUint = uint256(bytes32(_toAddress));

        bytes memory payload = abi.encode(toAddressUint, _amount);
        if (useCustomAdapterParams) {
            _checkGasLimit(_dstChainId, FUNCTION_TYPE_SEND, _adapterParams, NO_EXTRA_GAS);
        } else {
            require(_adapterParams.length == 0, "LzApp: _adapterParams must be empty.");
        }
        _lzSend(_dstChainId, payload, _from, _zroPaymentAddress, _adapterParams);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, // _nonce
        bytes memory _payload
    ) internal virtual override {
        // Decode and load toAddress
        (uint256 toAddressUint, uint256 amount) = abi.decode(_payload, (uint256, uint256));
        address toAddress = address(uint160(toAddressUint));

        _receiveMessage(_srcChainId, _srcAddress, toAddress, amount);
    }

    function _receiveMessage(uint16 _srcChainId, bytes memory _srcAddress, address _toAddress, uint256 _amount)
        internal
        virtual
    {
        // Privileges needed
        IUSX(usx).mint(_toAddress, _amount);

        emit ReceiveFromChain(_srcChainId, _srcAddress, _toAddress, _amount);
    }

    /**
     * @dev Obtain gas estimate for cross-chain transfer.
     * @param _dstChainId The Layer Zero destination chain ID.
     * @param _toAddress The recipient address on the destination chain.
     * @param _amount The amount to be transferred across chains.
     */
    function estimateSendFee(uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        public
        view
        virtual
        returns (uint256 nativeFee, uint256 zroFee)
    {
        // mock the payload for send()
        bytes memory payload = abi.encode(_toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, false, bytes(""));
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to use custom adapter params.
     * @param _useCustomAdapterParams Whether or not to use custom adapter params.
     */
    function setUseCustomAdapterParams(bool _useCustomAdapterParams) external onlyOwner {
        useCustomAdapterParams = _useCustomAdapterParams;
        emit SetUseCustomAdapterParams(_useCustomAdapterParams);
    }

    /**
     * @dev This function allows contract admins to extract any ERC20 token.
     * @param _token The address of token to remove.
     */
    function extractERC20(address _token) public onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        SafeTransferLib.safeTransfer(ERC20(_token), msg.sender, balance);
    }

    /**
     * @dev This function allows contract admins to extract this contract's native tokens.
     */
    function extractNative() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}