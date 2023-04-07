// SPDX-License-Identifier: UNLICENSED

//** DCB WalletStore Interface */
//** Author Aaron & Aceson : DCB 2023.2 */
pragma solidity 0.8.19;

interface IDCBWalletStore {
    function addUser(address _address) external returns (bool);

    function replaceUser(address oldAddress, address newAddress) external returns (bool);

    function getVerifiedUsers() external view returns (address[] memory);

    function isVerified(address) external view returns (bool);
}