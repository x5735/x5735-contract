//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Create3.sol";

contract Child {
    uint256 meaningOfLife;
    address owner;

    constructor(uint256 _meaning, address _owner) {
        meaningOfLife = _meaning;
        owner = _owner;
    }
}

contract Deployer {

    bytes32 internal constant KECCAK256_PROXY_CHILD_BYTECODE = 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    function deployChild() external {
        Create3.create3(
            keccak256("testuser12345"),
            abi.encodePacked(
                type(Child).creationCode,
                abi.encode(
                    42,
                    msg.sender
                )
            )
        );
    }

    function addressOfProxy(bytes32 _salt) external view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            address(this),
                            _salt,
                            KECCAK256_PROXY_CHILD_BYTECODE
                        )
                    )
                )
            )
        );
    }

    function addressOf(bytes32 _salt) external view returns (address) {
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            address(this),
                            _salt,
                            KECCAK256_PROXY_CHILD_BYTECODE
                        )
                    )
                )
            )
        );

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"d6_94",
                            proxy,
                            hex"01"
                        )
                    )
                )
            )
        );
    }

}