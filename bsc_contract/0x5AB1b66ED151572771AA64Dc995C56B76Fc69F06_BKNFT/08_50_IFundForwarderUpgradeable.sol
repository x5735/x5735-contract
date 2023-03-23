// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    IERC20Upgradeable
} from "../../oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {
    IERC721Upgradeable,
    IERC721EnumerableUpgradeable
} from "../../oz-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

interface IFundForwarderUpgradeable {
    error FundForwarder__InvalidArgument();

    struct RecoveryCallData {
        address token;
        uint256 value;
        bytes4 fnSelector;
        bytes params;
    }

    /**
     * @dev Emits when the vault address is updated
     * @param from Old vault address
     * @param to New vault address
     */
    event VaultUpdated(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    /**
     *@dev Emits when a single ERC721 token is recovered
     *@param operator Address of the contract calling this function
     *@param token Address of the token contract
     *@param value Token ID of the recovered token
     */
    event Recovered(
        address indexed operator,
        address indexed token,
        uint256 indexed value,
        bytes params
    );

    /**
     * @dev Emits when funds are forwarded
     * @param from Address of the sender
     * @param amount Amount of funds forwarded
     */
    event Forwarded(address indexed from, uint256 indexed amount);

    function safeRecoverHeader() external pure returns (bytes memory);

    function safeTransferHeader() external pure returns (bytes memory);

    function vault() external view returns (address);

    function changeVault(address vault_) external;

    /**
     * @dev Recovers native currency to the vault address
     */
    function recoverNative() external;

    function recover(RecoveryCallData[] calldata calldata_) external;
}