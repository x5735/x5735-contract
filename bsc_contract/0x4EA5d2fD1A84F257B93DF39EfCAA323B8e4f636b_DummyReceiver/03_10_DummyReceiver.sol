pragma solidity ^0.8.0;
pragma abicoder v2;

import "./lz/lzApp/NonblockingLzApp.sol";

contract DummyReceiver is NonblockingLzApp {
    bytes public constant PAYLOAD = "\x01\x02\x03\x04";
    // uint public counter;
    address[] public gauges;
    uint[] public amounts;

    constructor(address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {}

    // function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory) internal override {
    //     counter += 1;
    // }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual override {

        // (, bytes memory toAddressBytes, uint amount) = abi.decode(_payload, (uint16, bytes, uint));
        // address to = toAddressBytes.toAddress(0);
        (, address[] memory _gauges, uint[] memory _amounts) = abi.decode(_payload, (uint16, address[], uint[]));

        gauges = _gauges;
        amounts = _amounts;

        // uint16 packetType;
        // assembly {
        //     packetType := mload(add(_payload, 32))
        // }

        // if (packetType == PT_SEND) {
        //     _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        // } else {
        //     revert("OFTCore: unknown packet type");
        // }
    }

    function estimateFee(uint16 _dstChainId, bool _useZro, bytes calldata _adapterParams) public view returns (uint nativeFee, uint zroFee) {
        return lzEndpoint.estimateFees(_dstChainId, address(this), PAYLOAD, _useZro, _adapterParams);
    }

    // function incrementCounter(uint16 _dstChainId) public payable {
    //     _lzSend(_dstChainId, PAYLOAD, payable(msg.sender), address(0x0), bytes(""), msg.value);
    // }

    // function setOracle(uint16 dstChainId, address oracle) external onlyOwner {
    //     uint TYPE_ORACLE = 6;
    //     // set the Oracle
    //     lzEndpoint.setConfig(lzEndpoint.getSendVersion(address(this)), dstChainId, TYPE_ORACLE, abi.encode(oracle));
    // }

    // function getOracle(uint16 remoteChainId) external view returns (address _oracle) {
    //     bytes memory bytesOracle = lzEndpoint.getConfig(lzEndpoint.getSendVersion(address(this)), remoteChainId, address(this), 6);
    //     assembly {
    //         _oracle := mload(add(bytesOracle, 32))
    //     }
    // }
}